import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
public final class InstalledAppsScanner: ObservableObject {
    public static let shared = InstalledAppsScanner()
    
    @Published public var detectedApps: [LauncherAppItem] = []
    @Published public var isScanning: Bool = false
    
    private init() {
        scanInstalledApplications()
    }
    
    public func scanInstalledApplications() {
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = Self.performScan()
            
            DispatchQueue.main.async {
                self?.detectedApps = apps
                self?.isScanning = false
            }
        }
    }
    
    nonisolated private static func performScan() -> [LauncherAppItem] {
        let fileManager = FileManager.default
        let searchDirectories = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "\(fileManager.homeDirectoryForCurrentUser.path)/Applications",
            "/System/Library/CoreServices"
        ]
        
        var foundApps: [LauncherAppItem] = []
        var seenBundleIDs = Set<String>()
        var seenPaths = Set<String>()
        
        // Add Finder explicitly
        let finderPath = "/System/Library/CoreServices/Finder.app"
        if fileManager.fileExists(atPath: finderPath) {
            foundApps.append(LauncherAppItem(name: "Finder", bundleIdentifier: "com.apple.finder", path: finderPath))
            seenBundleIDs.insert("com.apple.finder")
            seenPaths.insert(finderPath)
        }
        
        for dir in searchDirectories {
            guard fileManager.fileExists(atPath: dir) else { continue }
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents where item.hasSuffix(".app") {
                let fullPath = "\(dir)/\(item)"
                guard !seenPaths.contains(fullPath) else { continue }
                
                let url = URL(fileURLWithPath: fullPath)
                guard let bundle = Bundle(url: url) else { continue }
                
                // Skip background agents unless it's a prominent utility
                let isUIElement = bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool ?? false
                let isBackground = bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool ?? false
                if isUIElement || isBackground {
                    continue
                }
                
                let bundleId = bundle.bundleIdentifier ?? ""
                if !bundleId.isEmpty && seenBundleIDs.contains(bundleId) {
                    continue
                }
                
                let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? item.replacingOccurrences(of: ".app", with: "")
                
                let appItem = LauncherAppItem(
                    name: displayName,
                    bundleIdentifier: bundleId,
                    path: fullPath
                )
                
                foundApps.append(appItem)
                seenPaths.insert(fullPath)
                if !bundleId.isEmpty {
                    seenBundleIDs.insert(bundleId)
                }
            }
        }
        
        return foundApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    public func promptChooseApplication(completion: @escaping (LauncherAppItem?) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Select Application"
        panel.prompt = "Add to Dock"
        panel.allowedContentTypes = [UTType.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            let bundle = Bundle(url: url)
            let bundleId = bundle?.bundleIdentifier ?? ""
            let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            
            let item = LauncherAppItem(name: name, bundleIdentifier: bundleId, path: path)
            completion(item)
        } else {
            completion(nil)
        }
    }
}
