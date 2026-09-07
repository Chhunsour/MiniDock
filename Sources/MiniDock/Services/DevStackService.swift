import Foundation
import Combine
import AppKit
import Darwin

public struct DevServiceItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let port: Int
    public let processName: String
    public let pid: Int
    public let urlString: String?
    public let projectPath: String?
    public let projectName: String?
    public let stack: String
    public let user: String?

    public init(
        id: String? = nil,
        name: String,
        port: Int,
        processName: String,
        pid: Int,
        urlString: String? = nil,
        projectPath: String? = nil,
        projectName: String? = nil,
        stack: String = "Service",
        user: String? = nil
    ) {
        self.id = id ?? "\(port):\(pid):\(processName)"
        self.name = name
        self.port = port
        self.processName = processName
        self.pid = pid
        self.urlString = urlString
        self.projectPath = projectPath
        self.projectName = projectName
        self.stack = stack
        self.user = user
    }

    public var isEligibleForShutdown: Bool {
        DevStackService.validateShutdownEligibility(service: self) == .eligible
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
            return "No Local Services"
        } else if count == 1 {
            return "1 Local Service"
        } else {
            return "\(count) Local Services"
        }
    }

    public var summarySubtext: String {
        guard let first = activeServices.first else {
            return "Nothing listening"
        }
        return "\(first.name) · :\(first.port)"
    }

    public func scanServices() {
        guard !isScanning else { return }
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

            return parseLsofOutput(
                text,
                cwdResolver: { pid in resolveCwd(for: pid) },
                commandLineResolver: { pid in resolveCommandLine(for: pid) }
            )
        } catch {
            return []
        }
    }

    nonisolated public static func parseLsofOutput(
        _ output: String,
        cwdResolver: ((Int) -> String?)? = nil,
        commandLineResolver: ((Int) -> String?)? = nil,
        fileChecker: ((String) -> Bool)? = nil
    ) -> [DevServiceItem] {
        struct CandidateListener {
            let command: String
            let pid: Int
            let port: Int
            let user: String
        }

        var candidates: [CandidateListener] = []
        var seenListeners = Set<String>()

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("COMMAND") {
                continue
            }

            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9 else { continue }

            let command = String(parts[0])
            guard let pid = Int(parts[1]) else { continue }
            let user = String(parts[2])

            // Extract port from NAME column (typically parts[8])
            // In lsof -P -n, the name is like *:3000, 127.0.0.1:3000, [::1]:3000, *:3306
            let nameField = String(parts[8])
            guard let colonIdx = nameField.lastIndex(of: ":") else { continue }
            let portPart = nameField[nameField.index(after: colonIdx)...]
            let portDigits = portPart.prefix(while: { $0.isNumber })
            guard let port = Int(portDigits), port > 0 && port < 65536 else { continue }

            // Deduplicate IPv4/IPv6 listeners without hiding another process
            // that happens to bind the same port on a different interface.
            let listenerKey = "\(pid):\(port)"
            if seenListeners.contains(listenerKey) {
                continue
            }

            // Exclude macOS internal tooling / daemons
            if isExcludedProcess(command: command) {
                continue
            }

            seenListeners.insert(listenerKey)
            candidates.append(CandidateListener(command: command, pid: pid, port: port, user: user))
        }

        var items: [DevServiceItem] = []
        for candidate in candidates {
            let cwd = cwdResolver?(candidate.pid)
            let commandLine = commandLineResolver?(candidate.pid)

            let projectInfo = findProjectRoot(from: cwd, fileChecker: fileChecker)

            let stackInfo = detectStack(
                command: candidate.command,
                commandLine: commandLine,
                markers: projectInfo?.markers ?? [],
                port: candidate.port
            )

            // Generic runtimes need project context, a conventional dev port,
            // or an explicit web-server signature such as Glances/Flask/Vite.
            if isGenericRuntime(candidate.command) &&
               projectInfo == nil &&
               !isRecognizedDevPort(candidate.port) &&
               !stackInfo.isWeb {
                continue
            }

            // High ports are normally internal IPC. Keep one only when the
            // process is positively classified as a web service.
            if isEphemeralPort(candidate.port) && !stackInfo.isWeb {
                continue
            }

            // Unknown low-port listeners are not automatically developer services.
            guard stackInfo.stack != "Service" ||
                    projectInfo != nil ||
                    isRecognizedDevPort(candidate.port) else {
                continue
            }

            let displayName: String
            if let projName = projectInfo?.projectName, !projName.isEmpty {
                displayName = projName
            } else {
                displayName = stackInfo.defaultName
            }

            let urlString = determineURL(port: candidate.port, isWeb: stackInfo.isWeb)
            let stableId = "\(candidate.port):\(candidate.pid):\(candidate.command)"

            let item = DevServiceItem(
                id: stableId,
                name: displayName,
                port: candidate.port,
                processName: candidate.command,
                pid: candidate.pid,
                urlString: urlString,
                projectPath: projectInfo?.projectPath,
                projectName: projectInfo?.projectName,
                stack: stackInfo.stack,
                user: candidate.user
            )
            items.append(item)
        }

        return items.sorted(by: { $0.port < $1.port })
    }

    nonisolated public static func isExcludedProcess(command: String) -> Bool {
        let cmd = command.lowercased()
        if cmd == "rapportd" ||
           cmd.hasPrefix("controlc") ||
           cmd == "adb" ||
           cmd.contains("figma") ||
           cmd.hasPrefix("antigravi") ||
           cmd.hasPrefix("language_") ||
           cmd == "electron" ||
           cmd == "google" ||
           cmd.hasPrefix("agent-bro") ||
           cmd == "runner" ||
           cmd == "launchd" ||
           cmd == "sharingd" ||
           cmd == "identityservicesd" ||
           cmd.contains("airplay") ||
           cmd.contains("universalaccess") ||
           cmd.contains("lsp") ||
           cmd == "sourcekit-lsp" ||
           cmd == "gopls" ||
           cmd == "pyright" ||
           cmd == "tsserver" ||
           cmd == "typescript-language-server" ||
           cmd == "rust-analyzer" ||
           cmd == "clangd" ||
           cmd == "jdtls" {
            return true
        }
        return false
    }

    nonisolated public static func isEphemeralPort(_ port: Int) -> Bool {
        return port >= 40000
    }

    nonisolated public static func isRecognizedDevPort(_ port: Int) -> Bool {
        switch port {
        case 80, 443, 3000...3010, 4000...4010, 4200, 4321, 5000, 5001, 5173...5179, 8000...8010, 8080...8090, 8443, 8888, 9000, 1337:
            return true
        default:
            return false
        }
    }

    nonisolated public static func isGenericRuntime(_ command: String) -> Bool {
        let cmd = command.lowercased()
        return cmd == "node" || cmd == "python" || cmd == "python3" ||
               cmd == "ruby" || cmd == "php" || cmd == "java" ||
               cmd == "go" || cmd == "deno" || cmd == "bun" || cmd == "perl"
    }

    nonisolated public static func findProjectRoot(
        from cwd: String?,
        fileChecker: ((String) -> Bool)? = nil
    ) -> (projectName: String, projectPath: String, markers: [String])? {
        guard let startPath = cwd, !startPath.isEmpty, startPath != "/" else { return nil }

        let checkFile = fileChecker ?? { path in FileManager.default.fileExists(atPath: path) }
        var current = URL(fileURLWithPath: startPath).standardized.path
        let stopPaths: Set<String> = ["/", "/Users", "/System", "/Library", "/Applications", "/private", "/var", "/tmp"]

        let candidateMarkers = [
            "package.json",
            "next.config.js", "next.config.mjs", "next.config.ts",
            "vite.config.js", "vite.config.ts", "vite.config.mjs",
            ".git",
            "pubspec.yaml",
            "Cargo.toml",
            "go.mod",
            "composer.json",
            "pyproject.toml", "requirements.txt", "Pipfile",
            "Gemfile",
            "pom.xml", "build.gradle", "build.gradle.kts"
        ]

        // Traverse up to 5 ancestor levels
        for _ in 0..<5 {
            if stopPaths.contains(current) || current.isEmpty {
                break
            }

            var foundMarkers: [String] = []
            for marker in candidateMarkers {
                let markerPath = (current as NSString).appendingPathComponent(marker)
                if checkFile(markerPath) {
                    foundMarkers.append(marker)
                }
            }

            if !foundMarkers.isEmpty {
                let name = URL(fileURLWithPath: current).lastPathComponent
                return (name.isEmpty ? current : name, current, foundMarkers)
            }

            let parent = (current as NSString).deletingLastPathComponent
            if parent == current {
                break
            }
            current = parent
        }

        return nil
    }

    nonisolated public static func detectStack(
        command: String,
        commandLine: String?,
        markers: [String],
        port: Int
    ) -> (stack: String, isWeb: Bool, defaultName: String) {
        let cmd = command.lowercased()
        let cmdLine = (commandLine ?? "").lowercased()

        // 1. Infrastructure / Databases by known ports and processes
        if port == 3306 || port == 33060 || cmd.contains("mysql") || cmd.contains("mariadb") {
            return ("Database", false, "MySQL")
        }
        if port == 5432 || cmd.contains("postgres") {
            return ("Database", false, "PostgreSQL")
        }
        if port == 6379 || cmd.contains("redis") {
            return ("Cache / KV", false, "Redis")
        }
        if port == 27017 || cmd.contains("mongo") {
            return ("Database", false, "MongoDB")
        }

        if cmdLine.contains("glances") && cmdLine.contains(" -w") {
            return ("System Monitor", true, "Glances")
        }

        // 2. Next.js
        if cmdLine.contains("next-server") || cmdLine.contains("next dev") || cmdLine.contains("next start") ||
           markers.contains(where: { $0.hasPrefix("next.config") }) {
            return ("Next.js", true, "Next.js App")
        }

        // 3. Vite
        if cmdLine.contains("vite") || markers.contains(where: { $0.hasPrefix("vite.config") }) {
            return ("Vite", true, "Vite Dev")
        }

        // 4. Node.js
        if cmd == "node" || cmd == "deno" || cmd == "bun" || markers.contains("package.json") {
            return ("Node.js", true, "Node Server")
        }

        // 5. Python
        if cmd.contains("python") || cmd == "gunicorn" || cmd == "uvicorn" ||
           cmdLine.contains("python") || cmdLine.contains("uvicorn") || cmdLine.contains("flask") ||
           markers.contains("pyproject.toml") || markers.contains("requirements.txt") || markers.contains("Pipfile") {
            let isWeb = isRecognizedDevPort(port) || cmdLine.contains("uvicorn") || cmdLine.contains("gunicorn") || cmdLine.contains("flask") || cmdLine.contains("http")
            return ("Python", isWeb, "Python Service")
        }

        // 6. PHP
        if cmd.contains("php") || markers.contains("composer.json") {
            return ("PHP", isRecognizedDevPort(port), "PHP Server")
        }

        // 7. Ruby
        if cmd.contains("ruby") || cmd.contains("puma") || cmd.contains("rails") || markers.contains("Gemfile") {
            return ("Ruby", isRecognizedDevPort(port), "Ruby Server")
        }

        // 8. Java
        if cmd.contains("java") || markers.contains("pom.xml") || markers.contains(where: { $0.hasPrefix("build.gradle") }) {
            return ("Java", isRecognizedDevPort(port), "Java Service")
        }

        // 9. Go
        if cmd == "go" || markers.contains("go.mod") {
            return ("Go", isRecognizedDevPort(port), "Go Service")
        }

        // 10. Rust
        if cmd.contains("cargo") || markers.contains("Cargo.toml") {
            return ("Rust", isRecognizedDevPort(port), "Rust Service")
        }

        let isWeb = isRecognizedDevPort(port)
        return ("Service", isWeb, "\(command.capitalized) :\(port)")
    }

    nonisolated public static func determineURL(port: Int, isWeb: Bool) -> String? {
        guard isWeb else { return nil }
        if port == 443 {
            return "https://localhost"
        } else if port == 8443 {
            return "https://localhost:8443"
        } else if port == 80 {
            return "http://localhost"
        } else {
            return "http://localhost:\(port)"
        }
    }

    nonisolated public static func resolveCwd(for pid: Int) -> String? {
        guard pid > 0 else { return nil }
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return nil }

            for line in text.components(separatedBy: .newlines) {
                if line.hasPrefix("n") && line.count > 1 {
                    let path = String(line.dropFirst())
                    return path.isEmpty ? nil : path
                }
            }
        } catch {}
        return nil
    }

    nonisolated public static func resolveCommandLine(for pid: Int) -> String? {
        guard pid > 0 else { return nil }
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", "\(pid)", "-o", "command="]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {}
        return nil
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

    // MARK: - Safe Service Shutdown

    public enum ShutdownType: Sendable {
        case graceful // SIGTERM
        case force    // SIGKILL
    }

    public enum ServiceShutdownEligibility: Equatable, Sendable {
        case eligible
        case ineligibleUser(owner: String?, currentUser: String)
        case ineligibleSystemPid(pid: Int)
        case ineligibleSelfPid(pid: Int)
        case ineligibleProtectedProcess(name: String)
    }

    nonisolated public static func validateShutdownEligibility(
        service: DevServiceItem,
        currentUser: String = NSUserName(),
        currentPid: Int = Int(ProcessInfo.processInfo.processIdentifier)
    ) -> ServiceShutdownEligibility {
        // 1. Owner check: must equal current user
        guard let owner = service.user, !owner.isEmpty, owner == currentUser else {
            return .ineligibleUser(owner: service.user, currentUser: currentUser)
        }

        // 2. PID check: must be > 1 (not kernel/init/launchd)
        guard service.pid > 1 else {
            return .ineligibleSystemPid(pid: service.pid)
        }

        // 3. MiniDock check: must not be MiniDock's PID
        guard service.pid != currentPid else {
            return .ineligibleSelfPid(pid: service.pid)
        }

        // 4. Process check: not in excluded/internal list, Docker daemon, or Finder
        let proc = service.processName.lowercased()
        if isExcludedProcess(command: proc) ||
           proc.contains("docker") ||
           proc == "dockerd" ||
           proc == "finder" ||
           proc == "minidock" {
            return .ineligibleProtectedProcess(name: service.processName)
        }

        return .eligible
    }

    nonisolated public static func parseAndValidateListener(
        lsofOutput: String,
        expectedPid: Int,
        expectedPort: Int,
        expectedProcessName: String,
        expectedUser: String
    ) -> Bool {
        let lines = lsofOutput.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("COMMAND") { continue }
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9 else { continue }

            let command = String(parts[0])
            guard let pid = Int(parts[1]) else { continue }
            guard pid == expectedPid else { continue }
            guard String(parts[2]) == expectedUser else { continue }

            let cleanCmd = command.lowercased()
            let cleanExpected = expectedProcessName.lowercased()
            guard cleanExpected.hasPrefix(cleanCmd) || cleanCmd.hasPrefix(cleanExpected) else {
                continue
            }

            let nameField = String(parts[8])
            guard let colonIdx = nameField.lastIndex(of: ":") else { continue }
            let portPart = nameField[nameField.index(after: colonIdx)...]
            let portDigits = portPart.prefix(while: { $0.isNumber })
            guard let port = Int(portDigits), port == expectedPort else { continue }

            if line.contains("LISTEN") {
                return true
            }
        }
        return false
    }

    nonisolated public static func revalidateListenerWithLsof(
        pid: Int,
        port: Int,
        processName: String,
        user: String
    ) -> Bool {
        guard pid > 1 else { return false }
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-a", "-p", "\(pid)", "-iTCP:\(port)", "-sTCP:LISTEN", "-P", "-n"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return false }
            return parseAndValidateListener(
                lsofOutput: text,
                expectedPid: pid,
                expectedPort: port,
                expectedProcessName: processName,
                expectedUser: user
            )
        } catch {
            return false
        }
    }

    public func stopService(
        _ service: DevServiceItem,
        type: ShutdownType
    ) async -> (success: Bool, message: String) {
        let result = await Task.detached(priority: .userInitiated) { () -> (Bool, String) in
            // 1. Verify eligibility
            let eligibility = Self.validateShutdownEligibility(service: service)
            guard eligibility == .eligible else {
                switch eligibility {
                case .ineligibleUser(let owner, let current):
                    return (false, "Cannot stop process owned by \(owner ?? "unknown") (current: \(current)).")
                case .ineligibleSystemPid(let pid):
                    return (false, "Cannot stop system process (PID \(pid)).")
                case .ineligibleSelfPid:
                    return (false, "Cannot stop MiniDock itself.")
                case .ineligibleProtectedProcess(let name):
                    return (false, "\(name) is a protected system or daemon process.")
                case .eligible:
                    return (false, "Service is not eligible to stop.")
                }
            }

            // 2. Revalidate live listener using direct lsof arguments
            let isStillLive = Self.revalidateListenerWithLsof(
                pid: service.pid,
                port: service.port,
                processName: service.processName,
                user: service.user ?? ""
            )
            guard isStillLive else {
                return (false, "Service on port \(service.port) (PID \(service.pid)) is no longer active.")
            }

            // 3. Send signal using Darwin.kill
            let signal: Int32 = (type == .force) ? SIGKILL : SIGTERM
            let killResult = Darwin.kill(pid_t(service.pid), signal)
            if killResult == 0 {
                let actionName = (type == .force) ? "Force stopped" : "Stopped"
                return (true, "\(actionName) \(service.name) (PID \(service.pid))")
            } else {
                let err = String(cString: strerror(errno))
                return (false, "Failed to signal process: \(err)")
            }
        }.value

        if result.0 {
            TransientCapsuleManager.shared.post(
                icon: type == .force ? "xmark.circle" : "power",
                title: result.1,
                detail: "Port :\(service.port) released",
                color: type == .force ? .red : .orange
            )
        } else {
            TransientCapsuleManager.shared.post(
                icon: "exclamationmark.triangle",
                title: "Shutdown Failed",
                detail: result.1,
                color: .red
            )
        }

        try? await Task.sleep(nanoseconds: 400_000_000)
        self.scanServices()

        return result
    }
}
