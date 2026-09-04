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

public enum FlowDockSettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case appearance = "Appearance"
    case apps = "Apps"
    case projects = "Projects"
    case workspaces = "Workspaces"
    case focus = "Focus"
    case commands = "Commands"
    case system = "System"
    case privacy = "Privacy"
    case advanced = "Advanced"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .apps: return "app.badge"
        case .projects: return "folder.badge.gearshape"
        case .workspaces: return "briefcase"
        case .focus: return "timer"
        case .commands: return "command"
        case .system: return "cpu"
        case .privacy: return "hand.raised"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // Geometry & Scale
    @Published public var dockScale: Double {
        didSet { defaults.set(dockScale, forKey: "dockScale") }
    }
    @Published public var iconSize: Double {
        didSet { defaults.set(iconSize, forKey: "iconSize") }
    }
    @Published public var dockSpacing: Double {
        didSet { defaults.set(dockSpacing, forKey: "dockSpacing") }
    }
    @Published public var cornerRadius: Double {
        didSet { defaults.set(cornerRadius, forKey: "cornerRadius") }
    }
    @Published public var flareWidth: Double {
        didSet { defaults.set(flareWidth, forKey: "flareWidth") }
    }
    @Published public var materialStyle: String {
        didSet { defaults.set(materialStyle, forKey: "materialStyle") }
    }
    @Published public var backgroundOpacity: Double {
        didSet { defaults.set(backgroundOpacity, forKey: "backgroundOpacity") }
    }
    @Published public var subtleGlowAmount: Double {
        didSet { defaults.set(subtleGlowAmount, forKey: "subtleGlowAmount") }
    }
    
    // Accent Color
    @Published public var useSystemAccent: Bool {
        didSet { defaults.set(useSystemAccent, forKey: "useSystemAccent") }
    }
    @Published public var accentColorName: String {
        didSet { defaults.set(accentColorName, forKey: "accentColorName") }
    }
    
    // Behavior & System
    @Published public var dockBehavior: String {
        didSet { defaults.set(dockBehavior, forKey: "dockBehavior") }
    }
    @Published public var dockPosition: String {
        didSet { defaults.set(dockPosition, forKey: "dockPosition") }
    }
    @Published public var displayTarget: String {
        didSet { defaults.set(displayTarget, forKey: "displayTarget") }
    }
    @Published public var animationSpeed: String {
        didSet { defaults.set(animationSpeed, forKey: "animationSpeed") }
    }
    @Published public var showOnFullscreen: Bool {
        didSet { defaults.set(showOnFullscreen, forKey: "showOnFullscreen") }
    }
    @Published public var runningIndicatorStyle: String {
        didSet { defaults.set(runningIndicatorStyle, forKey: "runningIndicatorStyle") }
    }
    
    // Core Toggles
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

    @Published public var focusDNDEnabled: Bool {
        didSet { defaults.set(focusDNDEnabled, forKey: "focusDNDEnabled") }
    }
    @Published public var focusSoundEnabled: Bool {
        didSet { defaults.set(focusSoundEnabled, forKey: "focusSoundEnabled") }
    }
    @Published public var systemPollInterval: Double {
        didSet { defaults.set(systemPollInterval, forKey: "systemPollInterval") }
    }
    
    public var activeAccentColor: Color {
        if useSystemAccent {
            return Color(nsColor: .controlAccentColor)
        }
        switch accentColorName {
        case "Blue": return .blue
        case "Purple": return .purple
        case "Orange": return .orange
        case "Green": return .green
        case "Pink": return .pink
        case "Cyan": return .cyan
        case "Graphite": return .gray
        default: return Color(nsColor: .controlAccentColor)
        }
    }

    private init() {
        self.dockScale = defaults.object(forKey: "dockScale") as? Double ?? 1.0
        self.iconSize = defaults.object(forKey: "iconSize") as? Double ?? 34.0
        self.dockSpacing = defaults.object(forKey: "dockSpacing") as? Double ?? 12.0
        self.cornerRadius = defaults.object(forKey: "cornerRadius") as? Double ?? 22.0
        self.flareWidth = defaults.object(forKey: "flareWidth") as? Double ?? 52.0
        self.materialStyle = defaults.string(forKey: "materialStyle") ?? "Dark Glass"
        self.backgroundOpacity = defaults.object(forKey: "backgroundOpacity") as? Double ?? 0.90
        self.subtleGlowAmount = defaults.object(forKey: "subtleGlowAmount") as? Double ?? 0.14
        
        self.useSystemAccent = defaults.object(forKey: "useSystemAccent") as? Bool ?? true
        self.accentColorName = defaults.string(forKey: "accentColorName") ?? "System"
        
        self.dockBehavior = defaults.string(forKey: "dockBehavior") ?? "Always Visible"
        self.dockPosition = defaults.string(forKey: "dockPosition") ?? "Bottom"
        self.displayTarget = defaults.string(forKey: "displayTarget") ?? "Primary Display"
        self.animationSpeed = defaults.string(forKey: "animationSpeed") ?? "Normal"
        self.showOnFullscreen = defaults.object(forKey: "showOnFullscreen") as? Bool ?? false
        self.runningIndicatorStyle = defaults.string(forKey: "runningIndicatorStyle") ?? "Dot"
        
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
        
        self.focusDNDEnabled = defaults.object(forKey: "focusDNDEnabled") as? Bool ?? false
        self.focusSoundEnabled = defaults.object(forKey: "focusSoundEnabled") as? Bool ?? true
        self.systemPollInterval = defaults.object(forKey: "systemPollInterval") as? Double ?? 2.0
    }
    
    public func resetToDefaults() {
        self.dockScale = 1.0
        self.iconSize = 34.0
        self.dockSpacing = 12.0
        self.cornerRadius = 22.0
        self.flareWidth = 52.0
        self.materialStyle = "Dark Glass"
        self.backgroundOpacity = 0.90
        self.subtleGlowAmount = 0.14
        self.useSystemAccent = true
        self.accentColorName = "System"
        self.dockBehavior = "Always Visible"
        self.dockPosition = "Bottom"
        self.displayTarget = "Primary Display"
        self.animationSpeed = "Normal"
        self.showOnFullscreen = false
        self.runningIndicatorStyle = "Dot"
        self.showFocus = true
        self.showLauncher = true
        self.showSystem = true
        self.showRepo = true
        self.preferredEditor = "Cursor"
        self.maskSensitiveClipboard = true
        self.smartSlotsEnabled = false
        self.focusDNDEnabled = false
        self.focusSoundEnabled = true
        self.systemPollInterval = 2.0
    }
}
