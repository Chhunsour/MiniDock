import SwiftUI
import AppKit

public struct AppLauncherWidgetView: View {
    @ObservedObject private var launcherService = AppLauncherService.shared
    @State private var hoveredAppId: UUID?
    @State private var pressedAppId: UUID?
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            HStack(spacing: 12) {
                ForEach(launcherService.apps) { app in
                    AppIconCell(
                        app: app,
                        icon: launcherService.icon(for: app),
                        isRunning: launcherService.isRunning(app),
                        isHovered: hoveredAppId == app.id,
                        isPressed: pressedAppId == app.id,
                        onHover: { hovering in
                            hoveredAppId = hovering ? app.id : nil
                        },
                        onTap: {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                pressedAppId = app.id
                            }
                            launcherService.launch(app)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation {
                                    pressedAppId = nil
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}

private struct AppIconCell: View {
    let app: LauncherAppItem
    let icon: NSImage
    let isRunning: Bool
    let isHovered: Bool
    let isPressed: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
                    .shadow(color: isHovered ? Color.white.opacity(0.35) : Color.black.opacity(0.3), radius: isHovered ? 5 : 2, x: 0, y: 1)
                    .scaleEffect(isPressed ? 0.90 : (isHovered ? 1.15 : 1.0))
                
                // Active Running Dot Indicator
                Circle()
                    .fill(isRunning ? Color.white.opacity(0.9) : Color.clear)
                    .frame(width: 3.5, height: 3.5)
                    .shadow(color: isRunning ? Color.white.opacity(0.6) : Color.clear, radius: 2)
            }
        }
        .buttonStyle(.plain)
        .help(app.name)
        .onHover { hovering in
            onHover(hovering)
        }
    }
}
