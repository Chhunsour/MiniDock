import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

public struct LauncherAppItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String
    public let fallbackPath: String
    
    public init(name: String, bundleIdentifier: String, fallbackPath: String) {
        self.id = UUID()
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.fallbackPath = fallbackPath
    }
}

@MainActor
public final class AppLauncherService: ObservableObject {
    public static let shared = AppLauncherService()
    
    @Published public var apps: [LauncherAppItem] = []
    @Published public var runningBundleIDs: Set<String> = []
    
    private var timer: AnyCancellable?
    
    private init() {
        self.apps = [
            LauncherAppItem(name: "Finder", bundleIdentifier: "com.apple.finder", fallbackPath: "/System/Library/CoreServices/Finder.app"),
            LauncherAppItem(name: "Terminal", bundleIdentifier: "com.apple.Terminal", fallbackPath: "/System/Applications/Utilities/Terminal.app"),
            LauncherAppItem(name: "VS Code", bundleIdentifier: "com.microsoft.VSCode", fallbackPath: "/Applications/Visual Studio Code.app"),
            LauncherAppItem(name: "Cursor", bundleIdentifier: "com.todesktop.230313mzl4w4u92", fallbackPath: "/Applications/Cursor.app"),
            LauncherAppItem(name: "Chrome", bundleIdentifier: "com.google.Chrome", fallbackPath: "/Applications/Google Chrome.app")
        ]
        
        updateRunningStatus()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateRunningStatus()
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateRunningStatus()
            }
        }
        
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateRunningStatus()
            }
    }
    
    public func updateRunningStatus() {
        let running = NSWorkspace.shared.runningApplications
        var activeIDs = Set<String>()
        for app in running {
            if let id = app.bundleIdentifier {
                activeIDs.insert(id)
            }
        }
        self.runningBundleIDs = activeIDs
    }
    
    public func isRunning(_ item: LauncherAppItem) -> Bool {
        if runningBundleIDs.contains(item.bundleIdentifier) {
            return true
        }
        if item.bundleIdentifier == "com.apple.finder" {
            return true
        }
        return false
    }
    
    public func icon(for item: LauncherAppItem) -> NSImage {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appUrl.path)
        }
        if FileManager.default.fileExists(atPath: item.fallbackPath) {
            return NSWorkspace.shared.icon(forFile: item.fallbackPath)
        }
        return NSWorkspace.shared.icon(for: UTType.application)
    }
    
    public func launch(_ item: LauncherAppItem) {
        let appName = item.name
        if item.bundleIdentifier == "com.apple.finder" {
            let script = "tell application \"Finder\" to activate"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            return
        }
        
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appUrl, configuration: config) { _, error in
                if let error = error {
                    print("Error opening \(appName): \(error.localizedDescription)")
                }
            }
            return
        }
        
        let fileUrl = URL(fileURLWithPath: item.fallbackPath)
        if FileManager.default.fileExists(atPath: item.fallbackPath) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: fileUrl, configuration: config) { _, error in
                if let error = error {
                    print("Error opening \(appName): \(error.localizedDescription)")
                }
            }
        }
    }
}
