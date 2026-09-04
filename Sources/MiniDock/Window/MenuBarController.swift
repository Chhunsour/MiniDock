import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject {
    public static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    
    private override init() {
        super.init()
        setupStatusItem()
        setupNotificationListener()
    }
    
    public func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        button.image = NSImage(systemSymbolName: "flowchart.fill", accessibilityDescription: "FlowDock")
        button.toolTip = "FlowDock Developer Command Center"
        
        let menu = NSMenu()
        
        let commandItem = NSMenuItem(title: "Command Palette (⌥ Space)", action: #selector(openCommandPalette), keyEquivalent: "")
        commandItem.target = self
        menu.addItem(commandItem)
        
        let focusItem = NSMenuItem(title: "Toggle Focus Session", action: #selector(toggleFocus), keyEquivalent: "")
        focusItem.target = self
        menu.addItem(focusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "FlowDock Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let toggleDockItem = NSMenuItem(title: "Toggle Apple Dock Auto-Hide", action: #selector(toggleAppleDock), keyEquivalent: "")
        toggleDockItem.target = self
        menu.addItem(toggleDockItem)
        
        let restoreDockItem = NSMenuItem(title: "Restore Standard Apple Dock", action: #selector(restoreAppleDock), keyEquivalent: "")
        restoreDockItem.target = self
        menu.addItem(restoreDockItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit FlowDock", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    private func setupNotificationListener() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: NSNotification.Name("OpenMiniDockSettings"),
            object: nil
        )
    }
    
    @objc public func openCommandPalette() {
        CommandPaletteWindowController.shared.toggle()
    }
    
    @objc public func toggleFocus() {
        FocusService.shared.togglePlayPause()
    }
    
    @objc public func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FlowDock Settings"
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        self.settingsWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc public func toggleAppleDock() {
        let settings = AppSettings.shared
        settings.autoHideAppleDock.toggle()
        DockManager.shared.setAppleDockAutoHide(settings.autoHideAppleDock)
    }
    
    @objc public func restoreAppleDock() {
        AppSettings.shared.autoHideAppleDock = false
        DockManager.shared.restoreAppleDock()
    }
    
    @objc public func quitApp() {
        DockManager.shared.restoreAppleDock()
        NSApplication.shared.terminate(nil)
    }
}
