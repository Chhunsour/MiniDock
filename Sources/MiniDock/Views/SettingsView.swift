import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var devStack = DevStackService.shared
    @ObservedObject private var repo = RepoService.shared
    
    public init() {}
    
    public var body: some View {
        TabView {
            // General & Appearance
            Form {
                Section("Appearance") {
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
                
                Section("System Dock & Startup") {
                    Toggle("Auto-Hide Apple Dock", isOn: $settings.autoHideAppleDock)
                        .onChange(of: settings.autoHideAppleDock) { _, newValue in
                            DockManager.shared.setAppleDockAutoHide(newValue)
                        }
                    
                    Toggle("Start MiniDock at Login", isOn: $settings.launchAtLogin)
                    
                    Button("Restore Apple Dock Now") {
                        DockManager.shared.restoreAppleDock()
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(18)
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            // Widgets Configuration
            Form {
                Section("Visible Widgets") {
                    Toggle("Clock & Date", isOn: $settings.showClock)
                    Toggle("Focus & Pomodoro Timer", isOn: $settings.showFocus)
                    Toggle("Developer Tool Launcher", isOn: $settings.showLauncher)
                    Toggle("System Performance Summary", isOn: $settings.showSystem)
                    Toggle("Dev Stack & Ports Monitor", isOn: $settings.showDevStack)
                    Toggle("Git Repo Context", isOn: $settings.showRepo)
                    Toggle("Now Playing Media (Compact)", isOn: $settings.showNowPlaying)
                }
            }
            .padding(18)
            .tabItem {
                Label("Widgets", systemImage: "square.grid.2x2")
            }
            
            // Developer Environment
            Form {
                Section("Active Project Repository") {
                    if repo.knownRepos.isEmpty {
                        Text("No git repositories detected in home directory.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Active Repo", selection: Binding(
                            get: { repo.currentRepo.repoPath },
                            set: { repo.selectRepo(at: $0) }
                        )) {
                            ForEach(repo.knownRepos, id: \.self) { path in
                                Text(URL(fileURLWithPath: path).lastPathComponent).tag(path)
                            }
                        }
                    }
                    
                    Button("Rescan Git Repositories") {
                        repo.findCandidateRepos()
                        repo.refreshRepoStatus()
                    }
                }
                
                Section("Developer Ports & Services") {
                    HStack {
                        Text("Detected Services:")
                        Spacer()
                        Text("\(devStack.activeServices.count) active")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Rescan Listening Ports") {
                        devStack.scanServices()
                    }
                }
            }
            .padding(18)
            .tabItem {
                Label("Developer", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
        .frame(width: 460, height: 380)
    }
}
