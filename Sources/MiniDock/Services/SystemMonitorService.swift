import Foundation
import Combine
import Darwin

@MainActor
public final class SystemMonitorService: ObservableObject {
    public static let shared = SystemMonitorService()
    
    @Published public var stats = SystemStats()
    
    private var timer: AnyCancellable?
    private var prevCpuLoad: host_cpu_load_info?
    private var prevNetBytes: (inBytes: UInt64, outBytes: UInt64, timestamp: Date)?
    
    private init() {
        updateStats()
        startMonitoring()
    }
    
    public func startMonitoring() {
        timer = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStats()
            }
    }
    
    public func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }
    
    public func updateStats() {
        var newStats = SystemStats()
        
        // 1. CPU Usage
        newStats.cpuUsage = calculateCPUUsage()
        
        // 2. RAM Usage
        let ram = calculateRAMUsage()
        newStats.ramUsage = ram.percentage
        newStats.ramUsedGB = ram.usedGB
        newStats.ramTotalGB = ram.totalGB
        
        // 3. Disk Usage
        let disk = calculateDiskUsage()
        newStats.diskUsage = disk.percentage
        newStats.diskUsedGB = disk.usedGB
        newStats.diskTotalGB = disk.totalGB
        
        // 4. Network Throughput
        let net = calculateNetworkSpeed()
        newStats.netDownloadKBps = net.downKBps
        newStats.netUploadKBps = net.upKBps
        
        self.stats = newStats
    }
    
    private func calculateCPUUsage() -> Double {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return stats.cpuUsage }
        
        guard let prev = prevCpuLoad else {
            prevCpuLoad = cpuLoad
            return 5.0
        }
        
        let userDiff = Double(cpuLoad.cpu_ticks.0 - prev.cpu_ticks.0)
        let sysDiff  = Double(cpuLoad.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDiff = Double(cpuLoad.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDiff = Double(cpuLoad.cpu_ticks.3 - prev.cpu_ticks.3)
        
        let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
        let usedTicks = userDiff + sysDiff + niceDiff
        
        prevCpuLoad = cpuLoad
        
        if totalTicks > 0 {
            let usage = (usedTicks / totalTicks) * 100.0
            return min(max(usage, 0.0), 100.0)
        }
        return stats.cpuUsage
    }
    
    private func calculateRAMUsage() -> (percentage: Double, usedGB: Double, totalGB: Double) {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(totalBytes) / (1024.0 * 1024.0 * 1024.0)
        
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return (50.0, totalGB * 0.5, totalGB)
        }
        
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        
        let active = Double(vmStats.active_count) * Double(pageSize)
        let wired = Double(vmStats.wire_count) * Double(pageSize)
        let compressed = Double(vmStats.compressor_page_count) * Double(pageSize)
        
        let usedBytes = active + wired + compressed
        let usedGB = usedBytes / (1024.0 * 1024.0 * 1024.0)
        let percentage = min(max((usedGB / totalGB) * 100.0, 0.0), 100.0)
        
        return (percentage, usedGB, totalGB)
    }
    
    private func calculateDiskUsage() -> (percentage: Double, usedGB: Double, totalGB: Double) {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            if let totalSize = attrs[.systemSize] as? NSNumber,
               let freeSize = attrs[.systemFreeSize] as? NSNumber {
                let totalBytes = totalSize.doubleValue
                let freeBytes = freeSize.doubleValue
                let usedBytes = totalBytes - freeBytes
                
                let totalGB = totalBytes / (1024.0 * 1024.0 * 1024.0)
                let usedGB = usedBytes / (1024.0 * 1024.0 * 1024.0)
                let percentage = min(max((usedGB / totalGB) * 100.0, 0.0), 100.0)
                return (percentage, usedGB, totalGB)
            }
        } catch {}
        return (25.0, 100.0, 500.0)
    }
    
    private func calculateNetworkSpeed() -> (downKBps: Double, upKBps: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddr) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let name = String(cString: p.pointee.ifa_name)
            if name.starts(with: "en"),
               let addr = p.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_LINK),
               let data = p.pointee.ifa_data {
                let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                totalIn += UInt64(ifData.ifi_ibytes)
                totalOut += UInt64(ifData.ifi_obytes)
            }
            ptr = p.pointee.ifa_next
        }
        
        let now = Date()
        guard let prev = prevNetBytes else {
            prevNetBytes = (totalIn, totalOut, now)
            return (0, 0)
        }
        
        let timeDelta = now.timeIntervalSince(prev.timestamp)
        guard timeDelta > 0.5 else {
            return (stats.netDownloadKBps, stats.netUploadKBps)
        }
        
        let inDelta = totalIn >= prev.inBytes ? totalIn - prev.inBytes : 0
        let outDelta = totalOut >= prev.outBytes ? totalOut - prev.outBytes : 0
        
        let downKBps = (Double(inDelta) / timeDelta) / 1024.0
        let upKBps = (Double(outDelta) / timeDelta) / 1024.0
        
        prevNetBytes = (totalIn, totalOut, now)
        return (downKBps, upKBps)
    }
}
