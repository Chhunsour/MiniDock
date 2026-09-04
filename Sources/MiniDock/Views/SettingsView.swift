import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var launcher = AppLauncherService.shared
    @ObservedObject private var devStack = DevStackService.shared
    @ObservedObject private var repo = RepoService.shared
    
    public init() {}
    
    public var body: some View {
        TabView {
            // 1. Launcher Management
            VStack(spacing: 0) {
                // Actions Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Apps (\(launcher.apps.count))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text("Drag ☰ to reorder apps on your Dock")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    
                    Button("+ Add Application") {
                        AppPickerWindowController.shared.present()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("Restore Defaults") {
                        launcher.restoreDefaultApps()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                // Reorderable Apps List
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
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.45))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                AppPickerWindowController.shared.present(replacingItem: app)
                            }) {
                                Text("Replace")
                                    .font(.system(size: 10))
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
                        .padding(.vertical, 3)
                    }
                    .onMove { indices, newOffset in
                        launcher.move(from: indices, to: newOffset)
                    }
                }
                .listStyle(.inset)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                // Visible items limit
                HStack {
                    Text("Visible Dock Limit:")
                        .font(.system(size: 11, weight: .medium))
                    Stepper("\(launcher.maxVisibleApps) apps", value: $launcher.maxVisibleApps, in: 3...12)
                        .font(.system(size: 11))
                    Spacer()
                    Button(launcher.isEditMode ? "Exit Dock Edit Mode" : "Open Edit Mode on Dock") {
                        withAnimation {
                            launcher.isEditMode.toggle()
                        }
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
            }
            .tabItem {
                Label("Launcher", systemImage: "app.badge")
            }
            
            // 2. Appearance
            Form {
                Section("Dock Appearance") {
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
            .padding(18)
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            // 3. Widgets
            Form {
                Section("Visible Widgets") {
                    Toggle("Clock & Date", isOn: $settings.showClock)
                    Toggle("Focus & Pomodoro Timer", isOn: $settings.showFocus)
                    Toggle("Developer Tool Launcher", isOn: $settings.showLauncher)
                    Toggle("System Performance Summary", isOn: $settings.showSystem)
                    Toggle("Dev Stack & Ports Monitor", isOn: $settings.showDevStack)
                    Toggle("Git Repo Context", isOn: $settings.showRepo)
                    Toggle("Secondary Glance (Now Playing & Clipboard)", isOn: $settings.showNowPlaying)
                }
            }
            .padding(18)
            .tabItem {
                Label("Widgets", systemImage: "square.grid.2x2")
            }
            
            // 4. Behavior & Apple Dock
            Form {
                Section("System Dock Integration") {
                    Toggle("Auto-Hide Apple Dock while MiniDock is active", isOn: $settings.autoHideAppleDock)
                        .onChange(of: settings.autoHideAppleDock) { _, newValue in
                            DockManager.shared.setAppleDockAutoHide(newValue)
                        }
                    
                    Button("Restore Apple Dock to Always Visible") {
                        DockManager.shared.restoreAppleDock()
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Startup") {
                    Toggle("Start MiniDock automatically at Login", isOn: $settings.launchAtLogin)
                }
                
                Section("Active Project Context") {
                    Picker("Git Repo", selection: Binding(
                        get: { repo.currentRepo.repoPath },
                        set: { repo.selectRepo(at: $0) }
                    )) {
                        ForEach(repo.knownRepos, id: \.self) { path in
                            Text(URL(fileURLWithPath: path).lastPathComponent).tag(path)
                        }
                    }
                    
                    Button("Rescan Candidate Repos") {
                        repo.findCandidateRepos()
                        repo.refreshRepoStatus()
                    }
                }
            }
            .padding(18)
            .tabItem {
                Label("Behavior", systemImage: "gearshape")
            }
        }
        .frame(width: 520, height: 430)
    }
}
