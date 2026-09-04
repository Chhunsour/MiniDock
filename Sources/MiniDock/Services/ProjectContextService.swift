import Foundation
import Combine
import AppKit

public struct ActiveProjectInfo: Sendable {
    public var path: String = ""
    public var name: String = "No Project"
    public var stackTypes: [ProjectStackType] = []
    public var gitBranch: String = "main"
    public var gitAheadCount: Int = 0
    public var gitBehindCount: Int = 0
    public var gitDirtyCount: Int = 0
    public var modifiedFiles: [String] = []
    public var lastCommitMessage: String = ""
    public var remoteURL: String? = nil
    public var gitHubURL: URL? = nil
    public var actions: [ProjectAction] = []
    
    public var isClean: Bool { gitDirtyCount == 0 }
    public var hasProject: Bool { !path.isEmpty }
    
    public var primaryStack: ProjectStackType {
        stackTypes.first ?? .general
    }
}

@MainActor
public final class ProjectContextService: ObservableObject {
    public static let shared = ProjectContextService()
    
    @Published public var project = ActiveProjectInfo()
    @Published public var candidateProjects: [String] = []
    @Published public var isRefreshing: Bool = false
    
    private var timer: AnyCancellable?
    private let activeProjectKey = "FlowDockActiveProjectPath"
    
    private init() {
        findCandidateProjects()
        
        // Restore last active project or default to first candidate
        if let saved = UserDefaults.standard.string(forKey: activeProjectKey),
           FileManager.default.fileExists(atPath: saved) {
            project.path = saved
        } else if let first = candidateProjects.first {
            project.path = first
        }
        
        refreshProjectContext()
        
        // Refresh git and project status periodically
        timer = Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshProjectContext()
            }
    }
    
    public func selectProject(at path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        project.path = path
        UserDefaults.standard.set(path, forKey: activeProjectKey)
        refreshProjectContext()
    }
    
    public func findCandidateProjects() {
        var paths: [String] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        
        let priorityPaths = [
            "\(home)/Projects/MiniDock",
            "\(home)/AttendKH-Website-Landing-Page",
            "\(home)/.gemini/antigravity/scratch/OpenMausBot"
        ]
        
        for p in priorityPaths {
            if FileManager.default.fileExists(atPath: p) && !paths.contains(p) {
                paths.append(p)
            }
        }
        
        let projectsDir = "\(home)/Projects"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) {
            for item in contents where !item.hasPrefix(".") {
                let full = "\(projectsDir)/\(item)"
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue {
                    if !paths.contains(full) {
                        paths.append(full)
                    }
                }
            }
        }
        
        self.candidateProjects = paths
        if project.path.isEmpty, let first = paths.first {
            project.path = first
        }
    }
    
    public func refreshProjectContext() {
        guard !project.path.isEmpty else {
            findCandidateProjects()
            return
        }
        
        let path = project.path
        let fm = FileManager.default
        let name = URL(fileURLWithPath: path).lastPathComponent
        
        // Detect Stacks
        var detectedStacks: [ProjectStackType] = []
        if fm.fileExists(atPath: "\(path)/pubspec.yaml") {
            detectedStacks.append(.flutter)
        }
        if fm.fileExists(atPath: "\(path)/package.json") {
            if fm.fileExists(atPath: "\(path)/next.config.js") ||
               fm.fileExists(atPath: "\(path)/next.config.mjs") ||
               fm.fileExists(atPath: "\(path)/next.config.ts") {
                detectedStacks.append(.nextjs)
            } else {
                detectedStacks.append(.nodejs)
            }
        }
        if fm.fileExists(atPath: "\(path)/composer.json") || fm.fileExists(atPath: "\(path)/artisan") {
            detectedStacks.append(.laravel)
        }
        if fm.fileExists(atPath: "\(path)/Cargo.toml") {
            detectedStacks.append(.rust)
        }
        if fm.fileExists(atPath: "\(path)/go.mod") {
            detectedStacks.append(.golang)
        }
        if fm.fileExists(atPath: "\(path)/docker-compose.yml") || fm.fileExists(atPath: "\(path)/compose.yml") {
            detectedStacks.append(.docker)
        }
        if fm.fileExists(atPath: "\(path)/supabase/config.toml") {
            detectedStacks.append(.supabase)
        }
        if detectedStacks.isEmpty {
            detectedStacks.append(.general)
        }
        
        // Generate contextual quick actions
        let actions = Self.generateActions(for: path, stacks: detectedStacks)
        
        let gitExists = fm.fileExists(atPath: "\(path)/.git")
        isRefreshing = true
        Task.detached { [weak self] in
            var branch = "main"
            var dirtyCount = 0
            var modifiedList: [String] = []
            var lastCommit = ""
            var ahead = 0
            var behind = 0
            var remoteUrl: String? = nil
            var ghUrl: URL? = nil
            
            if gitExists {
                // Branch
                if let b = Self.executeGit(["-C", path, "branch", "--show-current"])?.trimmingCharacters(in: .whitespacesAndNewlines), !b.isEmpty {
                    branch = b
                }
                
                // Status
                if let statusRaw = Self.executeGit(["-C", path, "status", "--porcelain"]) {
                    let lines = statusRaw.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    dirtyCount = lines.count
                    modifiedList = lines.map { String($0.prefix(60)) }
                }
                
                // Last commit
                if let log = Self.executeGit(["-C", path, "log", "-1", "--pretty=format:%s (%cr)"]) {
                    lastCommit = log
                }
                
                // Ahead / Behind
                if let ab = Self.executeGit(["-C", path, "rev-list", "--left-right", "--count", "\(branch)...@{upstream}"]) {
                    let parts = ab.split(separator: "\t")
                    if parts.count == 2 {
                        ahead = Int(parts[0]) ?? 0
                        behind = Int(parts[1]) ?? 0
                    }
                }
                
                // Remote origin URL
                if let remote = Self.executeGit(["-C", path, "config", "--get", "remote.origin.url"])?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    remoteUrl = remote
                    ghUrl = Self.parseGitHubURL(from: remote)
                }
            }
            
            await MainActor.run { [weak self] in
                var updated = ActiveProjectInfo()
                updated.path = path
                updated.name = name
                updated.stackTypes = detectedStacks
                updated.gitBranch = branch
                updated.gitDirtyCount = dirtyCount
                updated.modifiedFiles = modifiedList
                updated.lastCommitMessage = lastCommit
                updated.gitAheadCount = ahead
                updated.gitBehindCount = behind
                updated.remoteURL = remoteUrl
                updated.gitHubURL = ghUrl
                updated.actions = actions
                
                self?.project = updated
                self?.isRefreshing = false
            }
        }
    }
    
    // MARK: - Action Generator
    
    private static func generateActions(for path: String, stacks: [ProjectStackType]) -> [ProjectAction] {
        var actions: [ProjectAction] = []
        
        // 1. Universal editor & terminal actions
        actions.append(ProjectAction(
            title: "Open in Editor",
            subtitle: "VS Code / Cursor",
            icon: "macwindow",
            actionType: .openEditor
        ))
        
        actions.append(ProjectAction(
            title: "Open Terminal",
            subtitle: path,
            icon: "terminal",
            actionType: .openTerminal
        ))
        
        actions.append(ProjectAction(
            title: "Open Folder",
            subtitle: "Show in Finder",
            icon: "folder",
            actionType: .openFinder
        ))
        
        actions.append(ProjectAction(
            title: "View on GitHub",
            subtitle: "Open remote repo in browser",
            icon: "globe",
            actionType: .openGitHub
        ))
        
        // 2. Stack-specific actions
        for stack in stacks {
            switch stack {
            case .nextjs, .nodejs:
                actions.append(ProjectAction(
                    title: "Run Dev Server",
                    subtitle: "npm run dev",
                    icon: "play.circle.fill",
                    actionType: .runDevServer,
                    command: "npm run dev || pnpm dev || yarn dev"
                ))
                actions.append(ProjectAction(
                    title: "Run Tests",
                    subtitle: "npm test",
                    icon: "checkmark.seal",
                    actionType: .runTests,
                    command: "npm test"
                ))
                actions.append(ProjectAction(
                    title: "Run Build",
                    subtitle: "npm run build",
                    icon: "hammer",
                    actionType: .buildProject,
                    command: "npm run build"
                ))
                
            case .flutter:
                actions.append(ProjectAction(
                    title: "Run Flutter (macOS)",
                    subtitle: "flutter run -d macos",
                    icon: "play.circle.fill",
                    actionType: .runDevServer,
                    command: "flutter run -d macos"
                ))
                actions.append(ProjectAction(
                    title: "Build APK",
                    subtitle: "flutter build apk",
                    icon: "shippingbox",
                    actionType: .buildProject,
                    command: "flutter build apk"
                ))
                actions.append(ProjectAction(
                    title: "Flutter Clean",
                    subtitle: "flutter clean && pub get",
                    icon: "trash",
                    actionType: .runShellCommand,
                    command: "flutter clean && flutter pub get"
                ))
                
            case .laravel:
                actions.append(ProjectAction(
                    title: "Artisan Serve",
                    subtitle: "php artisan serve",
                    icon: "play.circle.fill",
                    actionType: .runDevServer,
                    command: "php artisan serve"
                ))
                actions.append(ProjectAction(
                    title: "Run Migrations",
                    subtitle: "php artisan migrate",
                    icon: "arrow.triangle.2.circlepath",
                    actionType: .runShellCommand,
                    command: "php artisan migrate"
                ))
                actions.append(ProjectAction(
                    title: "Optimize Clear",
                    subtitle: "php artisan optimize:clear",
                    icon: "trash",
                    actionType: .runShellCommand,
                    command: "php artisan optimize:clear"
                ))
                
            case .rust:
                actions.append(ProjectAction(
                    title: "Cargo Run",
                    subtitle: "cargo run",
                    icon: "play.circle.fill",
                    actionType: .runDevServer,
                    command: "cargo run"
                ))
                actions.append(ProjectAction(
                    title: "Cargo Test",
                    subtitle: "cargo test",
                    icon: "checkmark.seal",
                    actionType: .runTests,
                    command: "cargo test"
                ))
                
            case .golang:
                actions.append(ProjectAction(
                    title: "Go Run",
                    subtitle: "go run .",
                    icon: "play.circle.fill",
                    actionType: .runDevServer,
                    command: "go run ."
                ))
                actions.append(ProjectAction(
                    title: "Go Test",
                    subtitle: "go test ./...",
                    icon: "checkmark.seal",
                    actionType: .runTests,
                    command: "go test ./..."
                ))
                
            case .docker:
                actions.append(ProjectAction(
                    title: "Compose Up",
                    subtitle: "docker compose up -d",
                    icon: "cube.fill",
                    actionType: .runShellCommand,
                    command: "docker compose up -d"
                ))
                actions.append(ProjectAction(
                    title: "Compose Down",
                    subtitle: "docker compose down",
                    icon: "cube",
                    actionType: .runShellCommand,
                    command: "docker compose down"
                ))
                
            case .supabase:
                actions.append(ProjectAction(
                    title: "Supabase Start",
                    subtitle: "supabase start",
                    icon: "bolt.fill",
                    actionType: .runShellCommand,
                    command: "supabase start"
                ))
                
            case .general:
                break
            }
        }
        
        return actions
    }
    
    // MARK: - Action Execution
    
    public func executeAction(_ action: ProjectAction) {
        let path = project.path
        guard !path.isEmpty else { return }
        
        switch action.actionType {
        case .openEditor:
            openInBestEditor(path: path)
            TransientCapsuleManager.shared.post(
                icon: "macwindow",
                title: "Opening Editor",
                detail: project.name
            )
            
        case .openTerminal:
            openTerminal(at: path)
            TransientCapsuleManager.shared.post(
                icon: "terminal",
                title: "Opened Terminal",
                detail: project.name
            )
            
        case .openFinder:
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
            
        case .openGitHub:
            if let gh = project.gitHubURL {
                NSWorkspace.shared.open(gh)
            } else if let remote = project.remoteURL {
                TransientCapsuleManager.shared.post(
                    icon: "globe",
                    title: "Remote URL",
                    detail: remote
                )
            }
            
        case .runDevServer, .runTests, .buildProject, .runShellCommand, .custom:
            if let cmd = action.command {
                runCommandInTerminal(command: cmd, workingDir: path)
                TransientCapsuleManager.shared.post(
                    icon: "play.fill",
                    title: action.title,
                    detail: "Launched in Terminal"
                )
            }
        }
    }
    
    public func openInBestEditor(path: String) {
        let candidates = [
            ("Cursor", "/Applications/Cursor.app"),
            ("Visual Studio Code", "/Applications/Visual Studio Code.app"),
            ("Xcode", "/Applications/Xcode.app")
        ]
        
        for (_, appPath) in candidates {
            if FileManager.default.fileExists(atPath: appPath) {
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = ["-a", appPath, path]
                try? task.run()
                return
            }
        }
        
        // Fallback to default open
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        try? task.run()
    }
    
    public func openTerminal(at path: String) {
        let script = "tell application \"Terminal\" to do script \"cd \(path)\""
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        
        if let termUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: termUrl, configuration: config)
        }
    }
    
    public func runCommandInTerminal(command: String, workingDir: String) {
        let script = "tell application \"Terminal\" to do script \"cd \(workingDir) && \(command)\""
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        
        if let termUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: termUrl, configuration: config)
        }
    }
    
    // MARK: - Helpers
    
    nonisolated private static func executeGit(_ arguments: [String]) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/git"
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    nonisolated private static func parseGitHubURL(from remote: String) -> URL? {
        var clean = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasSuffix(".git") {
            clean = String(clean.dropLast(4))
        }
        
        // Handle SSH: git@github.com:user/repo
        if clean.hasPrefix("git@github.com:") {
            let path = clean.replacingOccurrences(of: "git@github.com:", with: "")
            return URL(string: "https://github.com/\(path)")
        }
        
        // Handle HTTPS
        if clean.hasPrefix("https://") || clean.hasPrefix("http://") {
            return URL(string: clean)
        }
        
        return nil
    }
}
