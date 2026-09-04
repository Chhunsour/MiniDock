import Foundation
import SwiftUI
import Combine

public enum SystemMetricType: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case ram = "RAM"
    case disk = "Disk"
    case combined = "Overall"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .ram: return "memorychip"
        case .disk: return "internaldrive"
        case .combined: return "gauge.with.needle"
        }
    }
}

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    @Published public var dockScale: Double {
        didSet { defaults.set(dockScale, forKey: "dockScale") }
    }
    @Published public var cornerRadius: Double {
        didSet { defaults.set(cornerRadius, forKey: "cornerRadius") }
    }
    @Published public var backgroundOpacity: Double {
        didSet { defaults.set(backgroundOpacity, forKey: "backgroundOpacity") }
    }
    @Published public var showFocus: Bool {
        didSet { defaults.set(showFocus, forKey: "showFocus") }
    }
    @Published public var showLauncher: Bool {
        didSet { defaults.set(showLauncher, forKey: "showLauncher") }
    }
    @Published public var showSystem: Bool {
        didSet { defaults.set(showSystem, forKey: "showSystem") }
    }
    @Published public var showRepo: Bool {
        didSet { defaults.set(showRepo, forKey: "showRepo") }
    }
    @Published public var autoHideAppleDock: Bool {
        didSet { defaults.set(autoHideAppleDock, forKey: "autoHideAppleDock") }
    }
    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    @Published public var preferredEditor: String {
        didSet { defaults.set(preferredEditor, forKey: "preferredEditor") }
    }
    @Published public var maskSensitiveClipboard: Bool {
        didSet { defaults.set(maskSensitiveClipboard, forKey: "maskSensitiveClipboard") }
    }
    @Published public var smartSlotsEnabled: Bool {
        didSet { defaults.set(smartSlotsEnabled, forKey: "smartSlotsEnabled") }
    }
    @Published public var commandShortcut: String {
        didSet { defaults.set(commandShortcut, forKey: "commandShortcut") }
    }

    private init() {
        self.dockScale = defaults.object(forKey: "dockScale") as? Double ?? 1.0
        self.cornerRadius = defaults.object(forKey: "cornerRadius") as? Double ?? 24.0
        self.backgroundOpacity = defaults.object(forKey: "backgroundOpacity") as? Double ?? 0.88
        self.showFocus = defaults.object(forKey: "showFocus") as? Bool ?? true
        self.showLauncher = defaults.object(forKey: "showLauncher") as? Bool ?? true
        self.showSystem = defaults.object(forKey: "showSystem") as? Bool ?? true
        self.showRepo = defaults.object(forKey: "showRepo") as? Bool ?? true
        self.autoHideAppleDock = defaults.object(forKey: "autoHideAppleDock") as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? true
        self.preferredEditor = defaults.string(forKey: "preferredEditor") ?? "Cursor"
        self.maskSensitiveClipboard = defaults.object(forKey: "maskSensitiveClipboard") as? Bool ?? true
        self.smartSlotsEnabled = defaults.object(forKey: "smartSlotsEnabled") as? Bool ?? false
        self.commandShortcut = defaults.string(forKey: "commandShortcut") ?? "⌥ Space"
    }
}
