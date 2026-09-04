import AppKit
import SwiftUI

@MainActor
public final class CommandPaletteWindowController: NSObject {
    public static let shared = CommandPaletteWindowController()
    
    private var window: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private override init() {
        super.init()
        setupGlobalShortcut()
    }
    
    public func setupGlobalShortcut() {
        // Option + Space (keyCode 49)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 49 {
                self?.toggle()
                return nil
            }
            return event
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 49 {
                DispatchQueue.main.async {
                    self?.toggle()
                }
            }
        }
    }
    
    public func toggle() {
        if window != nil && window?.isVisible == true {
            dismiss()
        } else {
            present()
        }
    }
    
    public func present() {
        if window == nil {
            createWindow()
        }
        
        guard let window = window else { return }
        
        // Center on screen
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - window.frame.width) / 2.0
            let y = screenRect.origin.y + (screenRect.height - window.frame.height) * 0.65
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func dismiss() {
        window?.orderOut(nil)
    }
    
    private func createWindow() {
        let panel = PalettePanel(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 440),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        
        let view = CommandPaletteView(onDismiss: { [weak self] in
            self?.dismiss()
        })
        
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        self.window = panel
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }
    
}

private final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
