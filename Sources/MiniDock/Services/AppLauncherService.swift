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
        Array(apps.prefix(maxVisibleApps))
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
    
    public func addApp(_ item: LauncherAppItem) {
        // Prevent duplicate bundle IDs if already in list
        if !item.bundleIdentifier.isEmpty && apps.contains(where: { $0.bundleIdentifier == item.bundleIdentifier }) {
            return
        }
        apps.append(item)
    }
    
    public func removeApp(id: UUID) {
        apps.removeAll { $0.id == id }
    }
    
    public func replaceApp(oldItem: LauncherAppItem, with newItem: LauncherAppItem) {
        if let index = apps.firstIndex(where: { $0.id == oldItem.id }) {
            apps[index] = newItem
        }
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
            return decoded
        }
        return defaultApps()
    }
    
    private func defaultApps() -> [LauncherAppItem] {
        return [
            LauncherAppItem(name: "Finder", bundleIdentifier: "com.apple.finder", path: "/System/Library/CoreServices/Finder.app"),
            LauncherAppItem(name: "Terminal", bundleIdentifier: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app"),
            LauncherAppItem(name: "VS Code", bundleIdentifier: "com.microsoft.VSCode", path: "/Applications/Visual Studio Code.app"),
            LauncherAppItem(name: "Cursor", bundleIdentifier: "com.todesktop.230313mzl4w4u92", path: "/Applications/Cursor.app"),
            LauncherAppItem(name: "Chrome", bundleIdentifier: "com.google.Chrome", path: "/Applications/Google Chrome.app")
        ]
    }
}
