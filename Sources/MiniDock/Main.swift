import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var strongDelegate: AppDelegate?
    
    private var dockPanel: MiniDockPanel?
    private var menuBarController: MenuBarController?
    private var signalSource: DispatchSourceSignal?
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        strongDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize menu bar item
        menuBarController = MenuBarController.shared
        
        // Create and present floating MiniDock panel
        dockPanel = MiniDockPanel()
        dockPanel?.orderFront(nil)
        
        // If configured, auto-hide standard Apple Dock
        if AppSettings.shared.autoHideAppleDock {
            DockManager.shared.setAppleDockAutoHide(true)
        }
        
        // Start developer and productivity services
        SystemMonitorService.shared.updateStats()
        DevStackService.shared.scanServices()
        RepoService.shared.findCandidateRepos()
        RepoService.shared.refreshRepoStatus()
        
        // Setup SIGUSR1 signal handler for CLI `minidock settings`
        signal(SIGUSR1, SIG_IGN)
        let sigSource = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        sigSource.setEventHandler {
            MenuBarController.shared.openSettings()
        }
        sigSource.resume()
        self.signalSource = sigSource
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.host == "settings" || url.path.contains("settings") {
                MenuBarController.shared.openSettings()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        DockManager.shared.restoreAppleDock()
    }
}
