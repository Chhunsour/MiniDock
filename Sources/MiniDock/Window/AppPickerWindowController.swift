import AppKit
import SwiftUI

@MainActor
public final class AppPickerWindowController: NSObject, NSWindowDelegate {
    public static let shared = AppPickerWindowController()
    
    private var pickerWindow: NSWindow?
    
    public func present(replacingItem: LauncherAppItem? = nil) {
        if let window = pickerWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = replacingItem == nil ? "Add Application to Dock" : "Replace Application"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        let pickerView = AppPickerSheet(replacingItem: replacingItem) { [weak self] _ in
            self?.pickerWindow?.close()
            self?.pickerWindow = nil
        } onDismiss: { [weak self] in
            self?.pickerWindow?.close()
            self?.pickerWindow = nil
        }
        
        window.contentView = NSHostingView(rootView: pickerView)
        self.pickerWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        self.pickerWindow = nil
    }
}
