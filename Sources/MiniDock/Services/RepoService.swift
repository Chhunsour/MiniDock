import Foundation
import Combine
import AppKit

public struct GitRepoContext: Sendable {
    public var repoName: String = "No Repo"
    public var repoPath: String = ""
    public var branch: String = "main"
    public var changedFilesCount: Int = 0
    public var modifiedFiles: [String] = []
    public var lastCommitMessage: String = ""
    public var isClean: Bool { changedFilesCount == 0 }
    public var hasRepo: Bool { !repoPath.isEmpty }
}

@MainActor
public final class RepoService: ObservableObject {
    public static let shared = RepoService()
    
    @Published public var currentRepo = GitRepoContext()
    @Published public var knownRepos: [String] = []
    @Published public var isRefreshing: Bool = false
    
    private var timer: AnyCancellable?
    
    private init() {
        findCandidateRepos()
        refreshRepoStatus()
        
        // Refresh every 5 seconds
        timer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshRepoStatus()
            }
    }
    
    public func findCandidateRepos() {
        var paths: [String] = []
        
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let checkPaths = [
            "\(home)/AttendKH-Website-Landing-Page",
            "\(home)/Projects/MiniDock",
            "\(home)/.gemini/antigravity/scratch/OpenMausBot"
        ]
        
        for path in checkPaths {
            if FileManager.default.fileExists(atPath: "\(path)/.git") {
                paths.append(path)
            }
        }
        
        let projectsDir = "\(home)/Projects"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) {
            for item in contents {
                let full = "\(projectsDir)/\(item)"
                if FileManager.default.fileExists(atPath: "\(full)/.git") && !paths.contains(full) {
                    paths.append(full)
                }
            }
        }
        
        self.knownRepos = paths
        if currentRepo.repoPath.isEmpty, let first = paths.first {
            currentRepo.repoPath = first
        }
    }
    
    public func selectRepo(at path: String) {
        currentRepo.repoPath = path
        refreshRepoStatus()
    }
    
    public func refreshRepoStatus() {
        guard !currentRepo.repoPath.isEmpty else {
            findCandidateRepos()
            return
        }
        
        let path = currentRepo.repoPath
        isRefreshing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let repoName = URL(fileURLWithPath: path).lastPathComponent
            
            // 1. Get branch
            let branch = Self.executeGit(["-C", path, "branch", "--show-current"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "main"
            
            // 2. Get status (porcelain)
            let statusRaw = Self.executeGit(["-C", path, "status", "--porcelain"]) ?? ""
            let statusLines = statusRaw.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            // 3. Last commit
            let lastCommit = Self.executeGit(["-C", path, "log", "-1", "--pretty=format:%s (%cr)"]) ?? ""
            
            DispatchQueue.main.async {
                var context = GitRepoContext()
                context.repoName = repoName
                context.repoPath = path
                context.branch = branch.isEmpty ? "HEAD" : branch
                context.changedFilesCount = statusLines.count
                context.modifiedFiles = statusLines.map { String($0.prefix(60)) }
                context.lastCommitMessage = lastCommit
                
                self?.currentRepo = context
                self?.isRefreshing = false
            }
        }
    }
    
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
    
    public func openInEditor(_ appName: String) {
        guard !currentRepo.repoPath.isEmpty else { return }
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", appName, currentRepo.repoPath]
        try? task.run()
    }
    
    public func openInTerminal() {
        guard !currentRepo.repoPath.isEmpty else { return }
        let script = "tell application \"Terminal\" to do script \"cd \(currentRepo.repoPath)\""
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        
        if let termUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: termUrl, configuration: config)
        }
    }
}
