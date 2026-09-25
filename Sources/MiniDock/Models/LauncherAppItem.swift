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
        let candidatePaths = [
            "/Applications/\(name).app",
            "/System/Applications/\(name).app",
            "/System/Applications/Utilities/\(name).app",
            "/Applications/\(name) IDE.app"
        ]
        for candidate in candidatePaths {
            if FileManager.default.fileExists(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }
    
    public var icon: NSImage {
        if let url = resolvedURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return Self.generateFallbackIcon(name: name)
    }

    private static func generateFallbackIcon(name: String) -> NSImage {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        
        let bounds = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 13, yRadius: 13)
        
        let gradient = NSGradient(
            colors: [
                NSColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1.0),
                NSColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1.0)
            ]
        )
        gradient?.draw(in: path, angle: -90)
        
        NSColor(white: 1.0, alpha: 0.22).setStroke()
        path.lineWidth = 1.0
        path.stroke()
        
        let initial = String(name.prefix(1)).uppercased()
        let font = NSFont.systemFont(ofSize: 26, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(white: 0.95, alpha: 0.95)
        ]
        let str = NSAttributedString(string: initial.isEmpty ? "A" : initial, attributes: attrs)
        let strSize = str.size()
        let strRect = NSRect(
            x: (size.width - strSize.width) / 2,
            y: (size.height - strSize.height) / 2 - 1,
            width: strSize.width,
            height: strSize.height
        )
        str.draw(in: strRect)
        
        image.unlockFocus()
        return image
    }
}
