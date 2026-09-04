import Foundation
import AppKit

@MainActor
public final class DockManager {
    public static let shared = DockManager()
    
    private let defaults = UserDefaults.standard
    private let originalKey = "originalAppleDockAutoHide"
    
    private init() {
        // Record initial state if not yet recorded
        if defaults.object(forKey: originalKey) == nil {
            let current = isAppleDockAutoHidden()
            defaults.set(current, forKey: originalKey)
        }
    }
    
    public func isAppleDockAutoHidden() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "com.apple.dock", "autohide"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output == "1" || output.lowercased() == "true"
            }
        } catch {}
        return false
    }
    
    public func setAppleDockAutoHide(_ autoHide: Bool) {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["write", "com.apple.dock", "autohide", "-bool", autoHide ? "true" : "false"]
        
        do {
            try task.run()
            task.waitUntilExit()
            restartDock()
        } catch {
            print("Failed to set dock autohide: \(error)")
        }
    }
    
    public func restoreAppleDock() {
        let original = defaults.bool(forKey: originalKey)
        setAppleDockAutoHide(original)
    }
    
    public func forceShowAppleDock() {
        setAppleDockAutoHide(false)
    }
    
    private func restartDock() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["Dock"]
        try? task.run()
    }
}
