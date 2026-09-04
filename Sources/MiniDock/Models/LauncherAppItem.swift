import Foundation
import AppKit
import UniformTypeIdentifiers

public struct LauncherAppItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var bundleIdentifier: String
    public var path: String
    
    public init(id: UUID = UUID(), name: String, bundleIdentifier: String, path: String) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
    }
    
    public var resolvedURL: URL? {
        if !bundleIdentifier.isEmpty,
           let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return appUrl
        }
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
    
    public var icon: NSImage {
        if let url = resolvedURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: UTType.application)
    }
}
