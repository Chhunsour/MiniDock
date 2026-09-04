import SwiftUI
import AppKit

public struct DockContainerView: View {
    @ObservedObject private var settings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 8) {
            // 1. Clock
            if settings.showClock {
                ClockWidgetView()
            }
            
            // 2. Focus Timer
            if settings.showFocus {
                FocusWidgetView()
            }
            
            // Subtle Section Divider
            if settings.showLauncher {
                SectionDivider()
                AppLauncherWidgetView()
            }
            
            // Subtle Section Divider
            if settings.showSystem || settings.showDevStack || settings.showRepo {
                SectionDivider()
            }
            
            // 4. System Summary
            if settings.showSystem {
                SystemWidgetView()
            }
            
            // 5. Dev Stack & Ports
            if settings.showDevStack {
                DevStackWidgetView()
            }
            
            // 6. Current Repo Context
            if settings.showRepo {
                RepoWidgetView()
            }
            
            // 7. Minimal Now Playing
            if settings.showNowPlaying {
                SectionDivider()
                NowPlayingWidgetView()
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            ZStack {
                // Glass Blur Material
                RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Deep obsidian neutral black tint
                RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10).opacity(settings.backgroundOpacity))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.55), radius: 30, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
        .scaleEffect(settings.dockScale)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.dockScale)
        .contextMenu {
            Button("MiniDock Settings...") {
                NotificationCenter.default.post(name: NSNotification.Name("OpenMiniDockSettings"), object: nil)
            }
            Divider()
            Button(settings.autoHideAppleDock ? "Unhide Apple Dock" : "Auto-Hide Apple Dock") {
                settings.autoHideAppleDock.toggle()
                DockManager.shared.setAppleDockAutoHide(settings.autoHideAppleDock)
            }
            Button("Restore Standard Apple Dock") {
                DockManager.shared.restoreAppleDock()
            }
            Divider()
            Button("Quit MiniDock") {
                DockManager.shared.restoreAppleDock()
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

private struct SectionDivider: View {
    var body: some View {
        Divider()
            .frame(height: 22)
            .background(Color.white.opacity(0.12))
            .padding(.horizontal, 2)
    }
}
