import SwiftUI
import AppKit

public struct DockContainerView: View {
    @ObservedObject private var settings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 10) {
            if settings.showClock {
                ClockWidgetView()
                    .transition(.scale.combined(with: .opacity))
            }
            
            if settings.showWeather {
                WeatherWidgetView()
                    .transition(.scale.combined(with: .opacity))
            }
            
            if settings.showLauncher {
                AppLauncherWidgetView()
                    .transition(.scale.combined(with: .opacity))
            }
            
            if settings.showSystem {
                SystemWidgetView()
                    .transition(.scale.combined(with: .opacity))
            }
            
            if settings.showNowPlaying {
                NowPlayingWidgetView()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Glass Blur Material
                RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Dark tinted acrylic overlay
                RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(settings.backgroundOpacity))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.26),
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.6), radius: 28, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 3)
        .scaleEffect(settings.dockScale)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.dockScale)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.showClock)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.showWeather)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.showLauncher)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.showSystem)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.showNowPlaying)
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
