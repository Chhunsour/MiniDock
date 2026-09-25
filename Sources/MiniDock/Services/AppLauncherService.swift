import Foundation
import AppKit
import Combine

@MainActor
public final class AppLauncherService: ObservableObject {
    public static let shared = AppLauncherService()
    
    private let defaultsKey = "userLauncherApps"
    private let maxAppsKey = "launcherMaxVisibleApps"
    
    @Published public var apps: [LauncherAppItem] = [] {
        didSet {
            saveApps()
        }
    }
    
    @Published public var maxVisibleApps: Int = 6 {
        didSet {
            UserDefaults.standard.set(maxVisibleApps, forKey: maxAppsKey)
        }
    }
    
    @Published public var isEditMode: Bool = false
    @Published public var isPickerPresented: Bool = false
    @Published public var targetReplaceItem: LauncherAppItem?
    
    @Published public var runningBundleIDs: Set<String> = []
    
    private var timer: AnyCancellable?
    
    private init() {
        self.maxVisibleApps = UserDefaults.standard.object(forKey: maxAppsKey) as? Int ?? 6
        self.apps = loadSavedApps()
        
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
    
    public var visibleApps: [LauncherAppItem] {
        if AppSettings.shared.showOnlyRunningApps {
            let running = apps.filter { isRunning($0) }
            return Array(running.prefix(maxVisibleApps))
        }
        return Array(apps.prefix(maxVisibleApps))
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
        if !item.bundleIdentifier.isEmpty && runningBundleIDs.contains(item.bundleIdentifier) {
            return true
        }
        if item.bundleIdentifier == "com.apple.finder" {
            return true
        }
        return false
    }
    
    // MARK: - App Actions
    
    public func launch(_ item: LauncherAppItem) {
        if item.bundleIdentifier == "com.apple.finder" {
            let script = "tell application \"Finder\" to activate"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            return
        }
        
        // If already running, bring to front
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == item.bundleIdentifier }
        if let first = runningApps.first {
            first.activate()
            return
        }
        
        if let appUrl = item.resolvedURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appUrl, configuration: config) { _, error in
                if let error = error {
                    print("Error opening \(item.name): \(error.localizedDescription)")
                }
            }
            return
        }
    }
    
    public func openNewWindow(_ item: LauncherAppItem) {
        if item.bundleIdentifier == "com.apple.finder" {
            let script = "tell application \"Finder\" to make new Finder window\ntell application \"Finder\" to activate"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            return
        }
        if let appUrl = item.resolvedURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: appUrl, configuration: config) { _, _ in }
            let script = "tell application id \"\(item.bundleIdentifier)\" to activate\ntell application \"System Events\" to tell process \"\(item.name)\" to keystroke \"n\" using command down"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
        }
    }
    
    public func hideApp(_ item: LauncherAppItem) {
        guard !item.bundleIdentifier.isEmpty else { return }
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == item.bundleIdentifier }
        for app in runningApps {
            app.hide()
        }
    }
    
    public func quitApp(_ item: LauncherAppItem) {
        guard !item.bundleIdentifier.isEmpty else { return }
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == item.bundleIdentifier }
        for app in runningApps {
            app.terminate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateRunningStatus()
        }
    }
    
    public func showInFinder(_ item: LauncherAppItem) {
        if let url = item.resolvedURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    // MARK: - List Management
    
    @discardableResult
    public func addOrPromoteApp(_ item: LauncherAppItem) -> Bool {
        var currentApps = self.apps
        var currentMax = self.maxVisibleApps
        let result = AppInsertionPolicy.apply(item: item, apps: &currentApps, maxVisibleApps: &currentMax)
        if result == .added || result == .promoted {
            self.apps = currentApps
            self.maxVisibleApps = currentMax
            return true
        }
        return false
    }

    public func addApp(_ item: LauncherAppItem) {
        addOrPromoteApp(item)
    }
    
    public func removeApp(id: UUID) {
        apps.removeAll { $0.id == id }
    }
    
    public func replaceApp(oldItem: LauncherAppItem, with newItem: LauncherAppItem) {
        guard let oldIndex = apps.firstIndex(where: { $0.id == oldItem.id }) else { return }
        apps[oldIndex] = newItem
    }
    
    public func moveApp(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              apps.indices.contains(sourceIndex),
              apps.indices.contains(destinationIndex) else { return }
        
        let item = apps.remove(at: sourceIndex)
        apps.insert(item, at: destinationIndex)
    }
    
    public func move(from source: IndexSet, to destination: Int) {
        apps.move(fromOffsets: source, toOffset: destination)
    }
    
    public func restoreDefaultApps() {
        self.apps = defaultApps()
    }
    
    // MARK: - Persistence
    
    private func saveApps() {
        do {
            let data = try JSONEncoder().encode(apps)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            print("Failed to save launcher apps: \(error)")
        }
    }
    
    private func loadSavedApps() -> [LauncherAppItem] {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([LauncherAppItem].self, from: data),
           !decoded.isEmpty {
            let healed = decoded.map { item -> LauncherAppItem in
                if item.name == "Cursor" && item.resolvedURL == nil {
                    if FileManager.default.fileExists(atPath: "/Applications/Xcode.app") {
                        return LauncherAppItem(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", path: "/Applications/Xcode.app")
                    } else if FileManager.default.fileExists(atPath: "/Applications/Antigravity.app") {
                        return LauncherAppItem(name: "Antigravity", bundleIdentifier: "com.google.antigravity", path: "/Applications/Antigravity.app")
                    }
                }
                return item
            }
            return healed
        }
        return defaultApps()
    }
    
    private func defaultApps() -> [LauncherAppItem] {
        var items = [
            LauncherAppItem(name: "Finder", bundleIdentifier: "com.apple.finder", path: "/System/Library/CoreServices/Finder.app"),
            LauncherAppItem(name: "Terminal", bundleIdentifier: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app"),
            LauncherAppItem(name: "VS Code", bundleIdentifier: "com.microsoft.VSCode", path: "/Applications/Visual Studio Code.app")
        ]
        if FileManager.default.fileExists(atPath: "/Applications/Xcode.app") {
            items.append(LauncherAppItem(name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", path: "/Applications/Xcode.app"))
        } else if FileManager.default.fileExists(atPath: "/Applications/Antigravity.app") {
            items.append(LauncherAppItem(name: "Antigravity", bundleIdentifier: "com.google.antigravity", path: "/Applications/Antigravity.app"))
        }
        items.append(LauncherAppItem(name: "Chrome", bundleIdentifier: "com.google.Chrome", path: "/Applications/Google Chrome.app"))
        return items
    }
}

/// Pure deterministic insertion and promotion policy for MiniDock launcher applications.
public struct AppInsertionPolicy: Sendable {
    public static let maxSupportedVisibleApps = 14

    public enum InsertionResult: Equatable, Sendable {
        case added
        case promoted
        case alreadyVisible
    }

    public static func matches(_ a: LauncherAppItem, _ b: LauncherAppItem) -> Bool {
        if !a.bundleIdentifier.isEmpty && !b.bundleIdentifier.isEmpty {
            return a.bundleIdentifier.lowercased() == b.bundleIdentifier.lowercased()
        }
        return a.path == b.path
    }

    @discardableResult
    public static func apply(
        item: LauncherAppItem,
        apps: inout [LauncherAppItem],
        maxVisibleApps: inout Int
    ) -> InsertionResult {
        // 1. Check if the app is already in the list
        if let existingIndex = apps.firstIndex(where: { matches($0, item) }) {
            if existingIndex < maxVisibleApps {
                // If already visible, do nothing and report that state
                return .alreadyVisible
            }

            // App exists but is hidden: promote existing item instead of duplicating it
            let existingItem = apps.remove(at: existingIndex)

            if maxVisibleApps < maxSupportedVisibleApps {
                // Insert at visible boundary and increment maxVisibleApps once
                let boundaryIndex = maxVisibleApps
                apps.insert(existingItem, at: boundaryIndex)
                maxVisibleApps += 1
                return .promoted
            } else {
                // At maximum 14: insert into last visible position (13) and move previous item to hidden segment
                let lastVisibleIndex = maxSupportedVisibleApps - 1
                apps.insert(existingItem, at: lastVisibleIndex)
                return .promoted
            }
        }

        // 2. App is new (not in list)
        if apps.count < maxVisibleApps {
            // Below the visible limit: append normally without changing the limit
            apps.append(item)
            return .added
        } else if maxVisibleApps < maxSupportedVisibleApps {
            // At/above limit and below maximum 14:
            // Insert at visible boundary and increment maxVisibleApps once
            let boundaryIndex = maxVisibleApps
            apps.insert(item, at: boundaryIndex)
            maxVisibleApps += 1
            return .added
        } else {
            // At maximum 14:
            // Insert into last visible position (13) and move previous item into saved hidden segment
            let lastVisibleIndex = maxSupportedVisibleApps - 1
            apps.insert(item, at: lastVisibleIndex)
            return .added
        }
    }
}
