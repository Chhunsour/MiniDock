import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var launcher = AppLauncherService.shared
    @ObservedObject private var projectService = ProjectContextService.shared
    @ObservedObject private var workspaceService = WorkspaceService.shared
    @ObservedObject private var focusService = FocusService.shared
    @ObservedObject private var monitorService = SystemMonitorService.shared
    @ObservedObject private var devStack = DevStackService.shared

    @State private var selectedTab: FlowDockSettingsTab

    public init(initialTab: FlowDockSettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Segmented Navigation Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(FlowDockSettingsTab.allCases) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 4.5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .fixedSize()
                            }
                            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.65))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(selectedTab == tab ? Color.white.opacity(0.14) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.04))

            Divider().background(Color.white.opacity(0.12))

            // Tab Content
            Group {
                switch selectedTab {
                case .general:
                    generalTab
                case .appearance:
                    appearanceTab
                case .apps:
                    appsTab
                case .projects:
                    projectsTab
                case .workspaces:
                    workspacesTab
                case .focus:
                    focusTab
                case .commands:
                    commandsTab
                case .system:
                    systemTab
                case .privacy:
                    privacyTab
                case .advanced:
                    advancedTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 530)
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
    }

    // MARK: - 1. General Tab
    private var generalTab: some View {
        Form {
            Section("FlowDock System Integration") {
                Toggle("Start FlowDock automatically at Login", isOn: $settings.launchAtLogin)

                Toggle("Auto-Hide standard Apple Dock", isOn: $settings.autoHideAppleDock)
                    .onChange(of: settings.autoHideAppleDock) { _, newValue in
                        DockManager.shared.setAppleDockAutoHide(newValue)
                    }

                Button("Restore Standard Apple Dock") {
                    DockManager.shared.restoreAppleDock()
                }
                .font(.system(size: 11))
            }

            Section("Display & Behavior") {
                Picker("Display Target", selection: $settings.displayTarget) {
                    Text("Primary Display").tag("Primary Display")
                    Text("Follow Active Window").tag("Follow Active Window")
                    Text("Display 1").tag("Display 1")
                    Text("Display 2").tag("Display 2")
                }

                Picker("Dock Behavior", selection: $settings.dockBehavior) {
                    Text("Auto-Hide (macOS Dock)").tag("Auto-Hide (macOS Dock)")
                    Text("Auto-Hide on Window Overlap (Intellihide)").tag("Auto-Hide on Window Overlap")
                    Text("Always Visible").tag("Always Visible")
                }

                Toggle("Keep FlowDock visible during Fullscreen apps", isOn: $settings.showOnFullscreen)
            }

            Section("Developer Defaults") {
                Picker("Preferred Code Editor", selection: $settings.preferredEditor) {
                    Text("Cursor").tag("Cursor")
                    Text("Visual Studio Code").tag("Visual Studio Code")
                    Text("Xcode").tag("Xcode")
                    Text("Sublime Text").tag("Sublime Text")
                }

                HStack {
                    Text("Command Palette Shortcut")
                    Spacer()
                    Text("⌥ Space (Option + Space)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(18)
    }

    // MARK: - 2. Appearance Tab (Live Preview)
    private var appearanceTab: some View {
        Form {
            Section("Live Dock Shell & Geometry (Instant Feedback)") {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Dock Scale")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.dockScale * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.dockScale, in: 0.8...1.3, step: 0.05)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Application Icon Size")
                        Spacer()
                        Text("\(Int(settings.iconSize)) pt")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.iconSize, in: 22...44, step: 1)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Slot Spacing")
                        Spacer()
                        Text("\(Int(settings.dockSpacing)) pt")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.dockSpacing, in: 4...18, step: 1)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Obsidian Glass Opacity")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.backgroundOpacity * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.backgroundOpacity, in: 0.4...0.98, step: 0.02)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Corner Radius")
                        Spacer()
                        Text("\(Int(settings.cornerRadius)) pt")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.cornerRadius, in: 16...32, step: 1)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Ambient Edge Glow")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.subtleGlowAmount * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.subtleGlowAmount, in: 0.0...0.6, step: 0.02)
                }
            }

            Section("Material & Translucency") {
                Picker("Surface Material", selection: $settings.materialStyle) {
                    Text("Fully Transparent ✨").tag("Fully Transparent")
                    Text("Obsidian Black").tag("Obsidian Black")
                    Text("Liquid Glass").tag("Liquid Glass")
                    Text("Dark Glass").tag("Dark Glass")
                    Text("Obsidian Vantablack").tag("Obsidian Vantablack")
                    Text("System Frost").tag("System Frost")
                }

                if settings.materialStyle == "Fully Transparent" {
                    Text("The dock background is fully transparent so your icons and widgets float seamlessly over your wallpaper and windows.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Section("Accent Color") {
                Toggle("Use macOS System Accent Color", isOn: $settings.useSystemAccent)

                if !settings.useSystemAccent {
                    Picker("Custom Color", selection: $settings.accentColorName) {
                        Text("Blue").tag("Blue")
                        Text("Purple").tag("Purple")
                        Text("Orange").tag("Orange")
                        Text("Green").tag("Green")
                        Text("Pink").tag("Pink")
                        Text("Cyan").tag("Cyan")
                        Text("Graphite").tag("Graphite")
                    }
                }
            }
        }
        .padding(18)
    }

    // MARK: - 3. Apps Tab
    private var appsTab: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pinned Applications (\(launcher.apps.count))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Drag ☰ to reorder apps · Live sync with Dock")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()

                Button("+ Add App") {
                    AppPickerWindowController.shared.present()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(launcher.isEditMode ? "Exit Edit Mode" : "Quick Edit Mode") {
                    withAnimation {
                        launcher.isEditMode.toggle()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Defaults") {
                    launcher.restoreDefaultApps()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(Color.white.opacity(0.03))

            Divider().background(Color.white.opacity(0.12))

            List {
                ForEach(launcher.apps) { app in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.white.opacity(0.35))
                            .font(.system(size: 12))

                        Image(nsImage: app.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .cornerRadius(5)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            Text(app.bundleIdentifier.isEmpty ? app.path : app.bundleIdentifier)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button("Replace") {
                            AppPickerWindowController.shared.present(replacingItem: app)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                        Button(action: {
                            launcher.removeApp(id: app.id)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
                .onMove { indices, newOffset in
                    launcher.move(from: indices, to: newOffset)
                }
            }
            .listStyle(.inset)

            Divider().background(Color.white.opacity(0.12))

            VStack(spacing: 10) {
                HStack(spacing: 18) {
                    HStack(spacing: 6) {
                        Text("Visible Limit:")
                            .font(.system(size: 11, weight: .medium))
                        Stepper("\(launcher.maxVisibleApps) apps", value: $launcher.maxVisibleApps, in: 3...14)
                            .font(.system(size: 11))
                    }

                    Picker("Active Indicator:", selection: $settings.runningIndicatorStyle) {
                        Text("Dot").tag("Dot")
                        Text("Bar").tag("Bar")
                        Text("Glow").tag("Glow")
                        Text("Off").tag("Off")
                    }
                    .font(.system(size: 11))
                    .frame(width: 170)
                    .onChange(of: settings.runningIndicatorStyle) { _, newValue in
                        settings.showRunningIndicators = (newValue != "Off")
                    }

                    Spacer()

                    Toggle("Smart Slots", isOn: $settings.smartSlotsEnabled)
                        .font(.system(size: 11))
                }

                HStack(spacing: 16) {
                    Toggle("Show indicator lights for open applications", isOn: Binding(
                        get: { settings.showRunningIndicators && settings.runningIndicatorStyle != "Off" },
                        set: { enabled in
                            settings.showRunningIndicators = enabled
                            if enabled && settings.runningIndicatorStyle == "Off" {
                                settings.runningIndicatorStyle = "Dot"
                            } else if !enabled {
                                settings.runningIndicatorStyle = "Off"
                            }
                        }
                    ))
                    .font(.system(size: 11))

                    Toggle("Show '+' button in dock", isOn: $settings.showAddAppButton)
                        .font(.system(size: 11))

                    Toggle("Show only open applications", isOn: $settings.showOnlyRunningApps)
                        .font(.system(size: 11))

                    Spacer()
                }
            }
            .padding(12)
        }
    }

    // MARK: - 4. Projects Tab
    private var projectsTab: some View {
        Form {
            Section("Current Project") {
                Picker("Active Project", selection: Binding(
                    get: { projectService.project.path },
                    set: { projectService.selectProject(at: $0) }
                )) {
                    ForEach(projectService.candidateProjects, id: \.self) { path in
                        Text(URL(fileURLWithPath: path).lastPathComponent).tag(path)
                    }
                }

                Button("Rescan Candidate Projects") {
                    projectService.findCandidateProjects()
                    projectService.refreshProjectContext()
                }
                .font(.system(size: 11))
            }

            Section("Project Details") {
                HStack {
                    Text("Detected Stacks")
                    Spacer()
                    Text(projectService.project.stackTypes.map(\.rawValue).joined(separator: ", "))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Git Branch")
                    Spacer()
                    Text(projectService.project.gitBranch)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Working Tree")
                    Spacer()
                    Text(projectService.project.isClean ? "Clean ✓" : "\(projectService.project.gitDirtyCount) changes")
                        .foregroundColor(projectService.project.isClean ? .green : .orange)
                }
                if !projectService.project.lastCommitMessage.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latest Commit")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(projectService.project.lastCommitMessage)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(18)
    }

    // MARK: - 5. Workspaces Tab
    private var workspacesTab: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Developer Workspaces (\(workspaceService.workspaces.count))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Preset environments with tools, folders, and browser URLs")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Button("Restore Presets") {
                    workspaceService.restoreDefaultWorkspaces()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(Color.white.opacity(0.03))

            Divider().background(Color.white.opacity(0.12))

            List {
                ForEach(workspaceService.workspaces) { ws in
                    HStack(spacing: 12) {
                        Image(systemName: ws.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.cyan)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(ws.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)

                            Text(ws.projectPath != nil ? URL(fileURLWithPath: ws.projectPath!).lastPathComponent : "General workspace")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        Button("Launch") {
                            workspaceService.launchWorkspace(ws)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 3)
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - 6. Focus Tab
    private var focusTab: some View {
        Form {
            Section("Active Session") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(focusService.isRunning ? "Active (\(focusService.formattedRemainingTime))" : "Resting")
                        .foregroundColor(focusService.isRunning ? .orange : .secondary)
                        .font(.system(size: 11, weight: .bold))
                }

                HStack {
                    Text("Completed Today")
                    Spacer()
                    Text("🔥 \(focusService.completedSessions) sessions")
                        .foregroundColor(.orange)
                        .font(.system(size: 11, weight: .semibold))
                }

                HStack(spacing: 10) {
                    Button(focusService.isRunning ? "Pause Session" : "Start Focus") {
                        focusService.togglePlayPause()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset") {
                        focusService.reset()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Quick Session Presets") {
                HStack(spacing: 8) {
                    Button("25m Focus") {
                        focusService.switchMode(.focus25)
                        focusService.start()
                    }
                    .buttonStyle(.bordered)

                    Button("50m Deep Work") {
                        focusService.switchMode(.focus50)
                        focusService.start()
                    }
                    .buttonStyle(.bordered)

                    Button("90m Flow State") {
                        focusService.switchMode(.focus90)
                        focusService.start()
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 8) {
                    Button("5m Short Break") {
                        focusService.switchMode(.shortBreak)
                        focusService.start()
                    }
                    .buttonStyle(.bordered)

                    Button("15m Long Break") {
                        focusService.switchMode(.longBreak)
                        focusService.start()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Focus Options") {
                Toggle("Do Not Disturb during active sessions", isOn: $settings.focusDNDEnabled)
                Toggle("Play chime audio alert on completion", isOn: $settings.focusSoundEnabled)
            }
        }
        .padding(18)
    }

    // MARK: - 7. Commands Tab
    private var commandsTab: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Command Palette")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Global Raycast-style quick launcher: ⌥ Space")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Button("Open Palette Now") {
                    CommandPaletteWindowController.shared.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            Divider().background(Color.white.opacity(0.12))

            List {
                CommandHelpRow(key: "⌥ Space", title: "Toggle Command Palette", category: "Global")
                CommandHelpRow(key: "Right-Click Dock", title: "Open FlowDock Context Menu", category: "Dock")
                CommandHelpRow(key: "Escape", title: "Exit Quick Edit Mode", category: "Dock")
                CommandHelpRow(key: "flowdock command", title: "Trigger palette via Terminal CLI", category: "CLI")
                CommandHelpRow(key: "flowdock restart", title: "Restart FlowDock process cleanly", category: "CLI")
                CommandHelpRow(key: "flowdock settings", title: "Open FlowDock Settings window", category: "CLI")
            }
            .listStyle(.inset)
        }
    }

    // MARK: - 8. System Tab
    private var systemTab: some View {
        Form {
            Section("Live Hardware Diagnostics") {
                HStack {
                    Text("CPU Load")
                    Spacer()
                    Text(String(format: "%.1f%%", monitorService.stats.cpuUsage))
                        .font(.system(size: 11, design: .monospaced))
                }
                HStack {
                    Text("RAM Used")
                    Spacer()
                    Text("\(String(format: "%.1f", monitorService.stats.ramUsedGB)) / \(String(format: "%.0f", monitorService.stats.ramTotalGB)) GB (\(Int(monitorService.stats.ramUsage))%)")
                        .font(.system(size: 11, design: .monospaced))
                }
                HStack {
                    Text("Free Disk Space")
                    Spacer()
                    Text("\(String(format: "%.0f", monitorService.stats.diskFreeGB)) GB available")
                        .font(.system(size: 11, design: .monospaced))
                }
                HStack {
                    Text("Network Speed")
                    Spacer()
                    Text("↓ \(monitorService.stats.formattedDownloadSpeed)  ↑ \(monitorService.stats.formattedUploadSpeed)")
                        .font(.system(size: 11, design: .monospaced))
                }

                Button("Open Activity Monitor") {
                    if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                        NSWorkspace.shared.open(appUrl)
                    }
                }
                .font(.system(size: 11))
            }

            Section("Dev Services") {
                HStack {
                    Text("Docker Engine")
                    Spacer()
                    Text(devStack.dockerRunning ? "Running (\(devStack.dockerContainersCount) containers)" : "Stopped")
                        .foregroundColor(devStack.dockerRunning ? .green : .secondary)
                }
            }
        }
        .padding(18)
    }

    // MARK: - 9. Privacy Tab
    private var privacyTab: some View {
        Form {
            Section("Security & Sensitive Data") {
                Toggle("Mask sensitive tokens in clipboard history (API keys, credentials)", isOn: $settings.maskSensitiveClipboard)

                Text("FlowDock operates completely locally on your Mac mini M4. No telemetry, code metadata, clipboard history, or activity logs leave your machine.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(18)
    }

    // MARK: - 10. Advanced Tab
    private var advancedTab: some View {
        Form {
            Section("Animation & Tuning") {
                Picker("Dock Animation Speed", selection: $settings.animationSpeed) {
                    Text("Instant").tag("Instant")
                    Text("Fast").tag("Fast")
                    Text("Normal").tag("Normal")
                    Text("Smooth").tag("Smooth")
                }
            }

            Section("Process & Lifecycle") {
                Button("Restart FlowDock") {
                    MenuBarController.shared.restartFlowDock()
                }
                .font(.system(size: 11))

                Button("Reset All Settings to Factory Defaults") {
                    settings.resetToDefaults()
                }
                .font(.system(size: 11))
                .foregroundColor(.red)

                Button("Quit FlowDock") {
                    MenuBarController.shared.quitApp()
                }
                .font(.system(size: 11))
            }
        }
        .padding(18)
    }
}

private struct CommandHelpRow: View {
    let key: String
    let title: String
    let category: String

    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.1)))

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            Text(category)
                .font(.system(size: 9.5))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(.vertical, 2)
    }
}
