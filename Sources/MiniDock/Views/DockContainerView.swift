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
            
            if settings.showSystem {
                SectionDivider()
                SystemWidgetView()
            }
            
            if settings.showDevStack {
                DevStackWidgetView()
            }
            
            if settings.showRepo {
                RepoWidgetView()
            }
            
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
