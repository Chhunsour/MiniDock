import Foundation
import Combine
import Darwin
import AppKit

@MainActor
public final class SystemMonitorService: ObservableObject {
    public static let shared = SystemMonitorService()

    @Published public var stats = SystemStats()
    @Published public var topApplications: [RunningApplicationUsage] = []

    private var timer: AnyCancellable?
    private var isSamplingApps = false
    private var prevCpuLoad: host_cpu_load_info?
    private var prevNetBytes: (inBytes: UInt64, outBytes: UInt64, timestamp: Date)?

    private init() {
        updateStats()
        sampleTopApplications()
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

        // 5. External Storage (/Volumes/Transcend)
        newStats.externalStorage = checkExternalStorage()

        self.stats = newStats

        // 6. Sample running applications (guarded against overlap)
        sampleTopApplications()
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
        storageUsage(at: "/") ?? (25.0, 100.0, 500.0)
    }

    private func storageUsage(at path: String) -> (percentage: Double, usedGB: Double, totalGB: Double)? {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
            if let totalSize = attrs[.systemSize] as? NSNumber,
               let freeSize = attrs[.systemFreeSize] as? NSNumber {
                let totalBytes = totalSize.doubleValue
                let freeBytes = freeSize.doubleValue
                guard totalBytes > 0 else { return nil }
                let usedBytes = max(totalBytes - freeBytes, 0.0)

                let totalGB = totalBytes / (1024.0 * 1024.0 * 1024.0)
                let usedGB = usedBytes / (1024.0 * 1024.0 * 1024.0)
                let percentage = min(max((usedGB / totalGB) * 100.0, 0.0), 100.0)
                return (percentage, usedGB, totalGB)
            }
        } catch {}
        return nil
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

    private func checkExternalStorage() -> VolumeStorageStats? {
        let keys: Set<URLResourceKey> = [.volumeNameKey]
        guard let volume = FileManager.default
            .mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes])?
            .first(where: { (try? $0.resourceValues(forKeys: keys).volumeName) == "Transcend" }),
              let usage = storageUsage(at: volume.path) else { return nil }

        return VolumeStorageStats(
            name: "Transcend",
            freeGB: max(usage.totalGB - usage.usedGB, 0.0),
            percentage: usage.percentage
        )
    }

    // MARK: - Top Running Applications & Force Quit

    public func sampleTopApplications() {
        guard !isSamplingApps else { return }
        isSamplingApps = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let samples = Self.runPsAndParse()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.topApplications = Self.resolveTopApplications(samples: samples)
                self.isSamplingApps = false
            }
        }
    }

    nonisolated private static func runPsAndParse() -> [pid_t: (cpu: Double, mem: Double)] {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-A", "-o", "pid=,%cpu=,%mem="]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [:] }
            return parsePsOutput(output)
        } catch {
            return [:]
        }
    }

    nonisolated public static func parsePsOutput(_ output: String) -> [pid_t: (cpu: Double, mem: Double)] {
        var results: [pid_t: (cpu: Double, mem: Double)] = [:]
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("PID") || trimmed.hasPrefix("%") {
                continue
            }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3 else { continue }
            guard let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let mem = Double(parts[2]) else {
                continue
            }
            results[pid] = (cpu: cpu, mem: mem)
        }
        return results
    }

    @MainActor
    public static func resolveTopApplications(
        samples: [pid_t: (cpu: Double, mem: Double)],
        currentPid: pid_t = ProcessInfo.processInfo.processIdentifier
    ) -> [RunningApplicationUsage] {
        let running = NSWorkspace.shared.runningApplications
        var list: [RunningApplicationUsage] = []

        for app in running {
            guard !app.isTerminated,
                  app.activationPolicy == .regular,
                  let bundleId = app.bundleIdentifier,
                  !bundleId.isEmpty else {
                continue
            }

            let pid = app.processIdentifier
            if pid == currentPid || bundleId == Bundle.main.bundleIdentifier {
                continue
            }
            if bundleId.lowercased() == "com.apple.finder" {
                continue
            }
            let lower = bundleId.lowercased()
            if lower.contains("loginwindow") ||
               lower.contains("systemuiserver") ||
               lower.contains("windowmanager") ||
               lower.contains("dock") {
                continue
            }

            let sample = samples[pid] ?? (cpu: 0.0, mem: 0.0)
            let name = app.localizedName ?? bundleId
            list.append(
                RunningApplicationUsage(
                    pid: pid,
                    name: name,
                    bundleIdentifier: bundleId,
                    cpuUsage: sample.cpu,
                    memoryUsage: sample.mem
                )
            )
        }

        return sortApplicationUsages(list)
    }

    public nonisolated static func sortApplicationUsages(_ apps: [RunningApplicationUsage]) -> [RunningApplicationUsage] {
        apps.sorted { a, b in
            if abs(a.cpuUsage - b.cpuUsage) > 0.01 {
                return a.cpuUsage > b.cpuUsage
            }
            if abs(a.memoryUsage - b.memoryUsage) > 0.01 {
                return a.memoryUsage > b.memoryUsage
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    public nonisolated static func matchesApplicationIdentity(
        _ selected: RunningApplicationUsage,
        livePid: pid_t,
        liveBundleIdentifier: String?
    ) -> Bool {
        selected.pid == livePid && selected.bundleIdentifier == liveBundleIdentifier
    }

    @discardableResult
    @MainActor
    public func quitApplication(_ selected: RunningApplicationUsage, force: Bool) -> (success: Bool, message: String) {
        guard let app = NSRunningApplication(processIdentifier: selected.pid) else {
            return (false, "Application (PID \(selected.pid)) is no longer running.")
        }
        guard Self.matchesApplicationIdentity(
            selected,
            livePid: app.processIdentifier,
            liveBundleIdentifier: app.bundleIdentifier
        ) else {
            return (false, "Application identity changed; refresh and try again.")
        }
        guard !app.isTerminated else {
            return (false, "Application is already terminated.")
        }
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return (false, "Cannot terminate MiniDock.")
        }
        guard app.bundleIdentifier?.lowercased() != "com.apple.finder" else {
            return (false, "Cannot terminate Finder.")
        }
        guard app.activationPolicy == .regular else {
            return (false, "Only regular GUI applications can be terminated.")
        }

        let appName = app.localizedName ?? "Application"
        let success: Bool
        if force {
            success = app.forceTerminate()
        } else {
            success = app.terminate()
        }

        let actionDesc = force ? "Force quit" : "Quit"
        if success {
            TransientCapsuleManager.shared.post(
                icon: force ? "xmark.circle" : "power",
                title: "\(actionDesc) \(appName)",
                detail: "PID \(selected.pid)",
                color: force ? .red : .orange
            )
        } else {
            TransientCapsuleManager.shared.post(
                icon: "exclamationmark.triangle",
                title: "\(actionDesc) Failed",
                detail: "\(appName) (PID \(selected.pid))",
                color: .red
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.sampleTopApplications()
        }

        return (success, success ? "\(actionDesc) \(appName)" : "Failed to \(actionDesc.lowercased()) \(appName)")
    }
}
