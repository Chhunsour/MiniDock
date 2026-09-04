import SwiftUI
import AppKit

public struct DockContainerView: View {
    @ObservedObject private var settings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 8) {
            // 1. Clock & Date
            if settings.showClock {
                ClockWidgetView()
            }
            
            // 2. Pomodoro Focus Timer
            if settings.showFocus {
                FocusWidgetView()
            }
            
            // 3. Custom App Launcher
            if settings.showLauncher {
                SectionDivider()
                AppLauncherWidgetView()
            }
            
            // 4. System Health Summary
            if settings.showSystem {
                SectionDivider()
                SystemWidgetView()
            }
            
            // 5. Dev Stack & Listening Ports
            if settings.showDevStack {
                DevStackWidgetView()
            }
            
            // 6. Active Git Repo Context
            if settings.showRepo {
                RepoWidgetView()
            }
            
            // 7. Secondary Glance (Now Playing & Clipboard)
            if settings.showNowPlaying {
                SectionDivider()
                SecondaryGlanceWidgetView()
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 28) // Clearance for the left & right flare fillets
        .padding(.top, 7)
        .padding(.bottom, 6)
        .background(
            ZStack {
                // Glass material
                EdgeFusedDockShape(flareWidth: 26, filletRadius: 20, cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                
                // Deep obsidian gradient fading to pitch black at screen edge
                EdgeFusedDockShape(flareWidth: 26, filletRadius: 20, cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.10, blue: 0.13).opacity(settings.backgroundOpacity),
                                Color(red: 0.04, green: 0.04, blue: 0.06).opacity(min(settings.backgroundOpacity + 0.08, 1.0))
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            // Hairline rim highlighting that dissolves gracefully into the bottom bezel
            EdgeFusedDockRim(flareWidth: 26, filletRadius: 20, cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.0), location: 0.0),
                            .init(color: Color.white.opacity(0.10), location: 0.06),
                            .init(color: Color.white.opacity(0.24), location: 0.25),
                            .init(color: Color.white.opacity(0.24), location: 0.75),
                            .init(color: Color.white.opacity(0.10), location: 0.94),
                            .init(color: Color.white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
        // Upward ambient shadow onto desktop wallpaper
        .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: -4)
        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: -1)
        .scaleEffect(settings.dockScale)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.dockScale)
    }
}

private struct SectionDivider: View {
    var body: some View {
        Divider()
            .frame(height: 20)
            .background(Color.white.opacity(0.10))
            .padding(.horizontal, 2)
    }
}
