import SwiftUI
import AppKit

public enum FlowDockSettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case launcher = "Launcher"
    case projects = "Projects"
    case workspaces = "Workspaces"
    case appearance = "Appearance"
    case privacy = "Privacy"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .launcher: return "app.badge"
        case .projects: return "folder.badge.gearshape"
        case .workspaces: return "briefcase"
        case .appearance: return "paintbrush"
        case .privacy: return "hand.raised"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var launcher = AppLauncherService.shared
    @ObservedObject private var projectService = ProjectContextService.shared
    @ObservedObject private var workspaceService = WorkspaceService.shared
    @State private var selectedTab: FlowDockSettingsTab = .general
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Segmented Navigation Bar
            HStack(spacing: 6) {
                ForEach(FlowDockSettingsTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 11.5, weight: .medium))
                                .fixedSize()
                        }
                        .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.65))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selectedTab == tab ? Color.white.opacity(0.14) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.04))
            
            Divider().background(Color.white.opacity(0.12))
            
            // Tab Content
            Group {
                switch selectedTab {
                case .general:
                    generalTab
                case .launcher:
                    launcherTab
                case .projects:
                    projectsTab
                case .workspaces:
                    workspacesTab
                case .appearance:
                    appearanceTab
                case .privacy:
                    privacyTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 640, height: 500)
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
            
            Section("Developer Defaults") {
                Picker("Default Code Editor", selection: $settings.preferredEditor) {
                    Text("Cursor").tag("Cursor")
                    Text("Visual Studio Code").tag("Visual Studio Code")
                    Text("Xcode").tag("Xcode")
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
        .padding(20)
    }
    
    // MARK: - 2. Launcher Tab
    private var launcherTab: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pinned Applications (\(launcher.apps.count))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Drag ☰ to reorder apps on your Dock")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                Button("+ Add App") {
                    AppPickerWindowController.shared.present()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Defaults") {
                    launcher.restoreDefaultApps()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)
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
            
            HStack {
                Text("Visible Dock Limit:")
                    .font(.system(size: 11, weight: .medium))
                Stepper("\(launcher.maxVisibleApps) apps", value: $launcher.maxVisibleApps, in: 3...14)
                    .font(.system(size: 11))
                Spacer()
                Toggle("Smart Slots", isOn: $settings.smartSlotsEnabled)
                    .font(.system(size: 11))
            }
            .padding(12)
        }
    }
    
    // MARK: - 3. Projects Tab
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
            }
        }
        .padding(20)
    }
    
    // MARK: - 4. Workspaces Tab
    private var workspacesTab: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Developer Workspaces (\(workspaceService.workspaces.count))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("One-click launch profiles for tools, folders, and URLs")
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
            .padding(14)
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
    
    // MARK: - 5. Appearance Tab
    private var appearanceTab: some View {
        Form {
            Section("Dock Shell & Screen-Edge Attachment") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Dock Scale")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.dockScale * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.dockScale, in: 0.8...1.25, step: 0.05)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Obsidian Glass Opacity")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.backgroundOpacity * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.backgroundOpacity, in: 0.5...0.98, step: 0.02)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Corner Radius")
                        Spacer()
                        Text("\(Int(settings.cornerRadius)) pt")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.cornerRadius, in: 18...32, step: 1)
                }
            }
        }
        .padding(20)
    }
    
    // MARK: - 6. Privacy Tab
    private var privacyTab: some View {
        Form {
            Section("Privacy Protection") {
                Toggle("Mask sensitive clipboard tokens (API keys, passwords)", isOn: $settings.maskSensitiveClipboard)
                
                Text("FlowDock runs 100% locally on your Mac mini M4. No telemetry, clipboard contents, repository paths, or system metrics are ever transmitted outside this device.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(20)
    }
}
