import Foundation
import AppKit
import Combine

@MainActor
public final class WorkspaceService: ObservableObject {
    public static let shared = WorkspaceService()
    
    private let storageKey = "FlowDockUserWorkspaces"
    
    @Published public var workspaces: [WorkspaceItem] = [] {
        didSet {
            saveWorkspaces()
        }
    }
    
    private init() {
        self.workspaces = loadWorkspaces()
    }
    
    public func launchWorkspace(_ ws: WorkspaceItem) {
        // 1. Set active project if configured
        if let path = ws.projectPath, FileManager.default.fileExists(atPath: path) {
            ProjectContextService.shared.selectProject(at: path)
        }
        
        // 2. Launch configured applications
        for bundleId in ws.appBundleIDs {
            if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: appUrl, configuration: config)
            }
        }
        
        // 3. Open URLs
        for urlStr in ws.urls {
            if let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
            }
        }
        
        // 4. Run optional terminal command
        if let cmd = ws.terminalCommand, !cmd.isEmpty, let path = ws.projectPath {
            ProjectContextService.shared.runCommandInTerminal(command: cmd, workingDir: path)
        }
        
        // 5. Optionally start Focus mode
        if let mins = ws.initialFocusMinutes, mins > 0 {
            FocusService.shared.startCustomDuration(minutes: mins, label: "\(ws.name) Focus")
        }
        
        // 6. Post transient capsule feedback
        TransientCapsuleManager.shared.post(
            icon: ws.icon,
            title: "Workspace Launched",
            detail: ws.name,
            color: .cyan,
            duration: 3.5
        )
    }
    
    public func addWorkspace(_ ws: WorkspaceItem) {
        workspaces.append(ws)
    }
    
    public func updateWorkspace(_ ws: WorkspaceItem) {
        if let idx = workspaces.firstIndex(where: { $0.id == ws.id }) {
            workspaces[idx] = ws
        }
    }
    
    public func removeWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
    }
    
    public func restoreDefaultWorkspaces() {
        self.workspaces = defaultWorkspaces()
    }
    
    private func saveWorkspaces() {
        if let data = try? JSONEncoder().encode(workspaces) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadWorkspaces() -> [WorkspaceItem] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([WorkspaceItem].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        return defaultWorkspaces()
    }
    
    private func defaultWorkspaces() -> [WorkspaceItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            WorkspaceItem(
                name: "Full-Stack Dev",
                icon: "chevron.left.forwardslash.chevron.right",
                projectPath: "\(home)/Projects/MiniDock",
                appBundleIDs: ["com.microsoft.VSCode", "com.apple.Terminal"],
                urls: ["http://localhost:3000"],
                initialFocusMinutes: 25,
                terminalCommand: nil
            ),
            WorkspaceItem(
                name: "Mobile Dev",
                icon: "iphone",
                projectPath: "\(home)/AttendKH-Website-Landing-Page",
                appBundleIDs: ["com.microsoft.VSCode", "com.apple.Terminal"],
                urls: [],
                initialFocusMinutes: 50,
                terminalCommand: nil
            ),
            WorkspaceItem(
                name: "Deep Focus",
                icon: "sparkles",
                projectPath: nil,
                appBundleIDs: ["com.apple.Terminal"],
                urls: [],
                initialFocusMinutes: 25,
                terminalCommand: nil
            )
        ]
    }
}
