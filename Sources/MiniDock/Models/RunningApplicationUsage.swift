import Foundation
import AppKit

public struct RunningApplicationUsage: Identifiable, Hashable, Sendable {
    public var id: Int { Int(pid) }
    public let pid: pid_t
    public let name: String
    public let bundleIdentifier: String
    public let cpuUsage: Double
    public let memoryUsage: Double

    public init(
        pid: pid_t,
        name: String,
        bundleIdentifier: String,
        cpuUsage: Double,
        memoryUsage: Double
    ) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
    }

    public var icon: NSImage {
        if let app = NSRunningApplication(processIdentifier: pid), let appIcon = app.icon {
            return appIcon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .application)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(bundleIdentifier)
    }

    public static func == (lhs: RunningApplicationUsage, rhs: RunningApplicationUsage) -> Bool {
        lhs.pid == rhs.pid &&
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        abs(lhs.cpuUsage - rhs.cpuUsage) < 0.01 &&
        abs(lhs.memoryUsage - rhs.memoryUsage) < 0.01
    }
}
