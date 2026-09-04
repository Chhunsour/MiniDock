import Foundation
import Combine
import AppKit

public struct DevServiceItem: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let port: Int
    public let processName: String
    public let pid: Int
    public let urlString: String?
    
    public init(name: String, port: Int, processName: String, pid: Int, urlString: String? = nil) {
        self.id = UUID()
        self.name = name
        self.port = port
        self.processName = processName
        self.pid = pid
        self.urlString = urlString
    }
}

@MainActor
public final class DevStackService: ObservableObject {
    public static let shared = DevStackService()
    
    @Published public var activeServices: [DevServiceItem] = []
    @Published public var dockerRunning: Bool = false
    @Published public var dockerContainersCount: Int = 0
    @Published public var isScanning: Bool = false
    
    private var timer: AnyCancellable?
    
    private init() {
        scanServices()
        // Poll every 4 seconds
        timer = Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.scanServices()
            }
    }
    
    public var summaryHeadline: String {
        let count = activeServices.count
        if count == 0 {
            return dockerRunning ? "Docker Active" : "No Local Ports"
        } else if count == 1 {
            return activeServices.first?.name ?? "1 Service"
        } else {
            return "\(count) Services"
        }
    }
    
    public var summarySubtext: String {
        if activeServices.isEmpty {
            return dockerRunning ? "\(dockerContainersCount) containers" : "Idle stack"
        }
        let names = activeServices.prefix(2).map { $0.port > 0 ? "\($0.name) :\($0.port)" : $0.name }
        return names.joined(separator: " · ")
    }
    
    public func scanServices() {
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let services = Self.detectListeningServices()
            let (dockerIsRunning, dockerCount) = Self.checkDocker()
            
            DispatchQueue.main.async {
                self?.activeServices = services
                self?.dockerRunning = dockerIsRunning
                self?.dockerContainersCount = dockerCount
                self?.isScanning = false
            }
        }
    }
    
    nonisolated private static func detectListeningServices() -> [DevServiceItem] {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return [] }
            
            return parseLsofOutput(text)
        } catch {
            return []
        }
    }
    
    nonisolated private static func parseLsofOutput(_ output: String) -> [DevServiceItem] {
        var items: [DevServiceItem] = []
        var seenPorts = Set<Int>()
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines.dropFirst() {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9 else { continue }
            
            let command = String(parts[0])
            let pid = Int(parts[1]) ?? 0
            let nameField = String(parts[8])
            
            guard let portStr = nameField.components(separatedBy: ":").last,
                  let port = Int(portStr) else { continue }
            
            if command == "rapportd" || command.starts(with: "Control") || command == "Python" && port > 50000 {
                continue
            }
            if port >= 40000 {
                continue
            }
            if seenPorts.contains(port) {
                continue
            }
            seenPorts.insert(port)
            
            let friendlyName: String
            let url: String?
            
            switch port {
            case 3000:
                friendlyName = "Node (App)"
                url = "http://localhost:3000"
            case 5173:
                friendlyName = "Vite (Dev)"
                url = "http://localhost:5173"
            case 8000:
                friendlyName = "API (8000)"
                url = "http://localhost:8000"
            case 8080:
                friendlyName = "Server (8080)"
                url = "http://localhost:8080"
            case 3306, 33060:
                friendlyName = "MySQL"
                url = nil
            case 5432:
                friendlyName = "PostgreSQL"
                url = nil
            case 6379:
                friendlyName = "Redis"
                url = nil
            case 27017:
                friendlyName = "MongoDB"
                url = nil
            default:
                friendlyName = "\(command.capitalized) :\(port)"
                url = "http://localhost:\(port)"
            }
            
            items.append(DevServiceItem(name: friendlyName, port: port, processName: command, pid: pid, urlString: url))
        }
        
        return items.sorted(by: { $0.port < $1.port })
    }
    
    nonisolated private static func checkDocker() -> (isRunning: Bool, containers: Int) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "which docker >/dev/null 2>&1 && docker ps -q 2>/dev/null | wc -l || echo 'OFF'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if output == "OFF" {
                    return (false, 0)
                }
                if let count = Int(output) {
                    return (true, count)
                }
            }
        } catch {}
        return (false, 0)
    }
    
    public func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
