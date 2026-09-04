import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var strongDelegate: AppDelegate?
    
    private var dockPanel: MiniDockPanel?
    private var menuBarController: MenuBarController?
    private var sigusr1Source: DispatchSourceSignal?
    private var sigusr2Source: DispatchSourceSignal?
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        strongDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize menu bar item & command palette
        menuBarController = MenuBarController.shared
        _ = CommandPaletteWindowController.shared
        _ = WorkspaceService.shared
        
        // Create and present edge-fused FlowDock panel
        dockPanel = MiniDockPanel()
        dockPanel?.orderFront(nil)
        
        // If configured, auto-hide standard Apple Dock
        if AppSettings.shared.autoHideAppleDock {
            DockManager.shared.setAppleDockAutoHide(true)
        }
        
        // Start developer and productivity services
        SystemMonitorService.shared.updateStats()
        DevStackService.shared.scanServices()
        ProjectContextService.shared.findCandidateProjects()
        ProjectContextService.shared.refreshProjectContext()
        _ = ClipboardService.shared
        
        // Setup SIGUSR1 signal handler for CLI `flowdock settings`
        signal(SIGUSR1, SIG_IGN)
        let s1 = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        s1.setEventHandler {
            MenuBarController.shared.openSettings()
        }
        s1.resume()
        self.sigusr1Source = s1
        
        // Setup SIGUSR2 signal handler for CLI `flowdock command`
        signal(SIGUSR2, SIG_IGN)
        let s2 = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
        s2.setEventHandler {
            CommandPaletteWindowController.shared.toggle()
        }
        s2.resume()
        self.sigusr2Source = s2
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let spec = ((url.host ?? "") + "/" + url.path).lowercased()
            if spec.contains("settings") {
                if spec.contains("appearance") {
                    MenuBarController.shared.openSettings(tab: .appearance)
                } else if spec.contains("apps") {
                    MenuBarController.shared.openSettings(tab: .apps)
                } else if spec.contains("projects") {
                    MenuBarController.shared.openSettings(tab: .projects)
                } else if spec.contains("focus") {
                    MenuBarController.shared.openSettings(tab: .focus)
                } else {
                    MenuBarController.shared.openSettings()
                }
            } else if spec.contains("command") {
                CommandPaletteWindowController.shared.toggle()
            } else if spec.contains("edit") {
                Task { @MainActor in
                    withAnimation {
                        AppLauncherService.shared.isEditMode.toggle()
                    }
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        DockManager.shared.restoreAppleDock()
    }
}
