import SwiftUI
import AppKit

public struct DockContainerView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var transient = TransientCapsuleManager.shared
    @State private var isDockHovered = false
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: isDockHovered ? 10 : 8) {
            // 1. Focus Pill (Minimal ◉ 25m)
            if settings.showFocus {
                FocusWidgetView()
            }
            
            // 2. User-Selected Pinned Applications (+ inline Add)
            if settings.showLauncher {
                SectionDivider()
                AppLauncherWidgetView()
            }
            
            // 3. Current Project Capsule (Project ✓ branch)
            if settings.showRepo {
                SectionDivider()
                ProjectCapsuleView()
            }
            
            // 4. Contextual Area: Transient Event or Exception-First Health
            if transient.activeEvent != nil {
                SectionDivider()
                TransientCapsuleView()
            } else if settings.showSystem {
                SectionDivider()
                SystemWidgetView()
            }
            
            // 5. Command Palette Trigger Button (Revealed on hover or minimal)
            Button(action: {
                CommandPaletteWindowController.shared.toggle()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "command")
                        .font(.system(size: 10, weight: .bold))
                    if isDockHovered {
                        Text("Space")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .transition(.opacity)
                    }
                }
                .foregroundColor(.white.opacity(isDockHovered ? 0.8 : 0.35))
                .padding(.horizontal, isDockHovered ? 7 : 5)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(isDockHovered ? 0.10 : 0.0))
                )
            }
            .buttonStyle(.plain)
            .help("FlowDock Command Palette (⌥ Space)")
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 28) // Clearance for left & right concave fillet flares
        .padding(.top, isDockHovered ? 8 : 6)
        .padding(.bottom, isDockHovered ? 6 : 5)
        .background(
            ZStack {
                // Glass material
                EdgeFusedDockShape(flareWidth: 26, filletRadius: 20, cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                
                // Deep obsidian gradient fading smoothly into bottom monitor bezel
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
                            .init(color: Color.white.opacity(0.12), location: 0.06),
                            .init(color: Color.white.opacity(isDockHovered ? 0.32 : 0.22), location: 0.25),
                            .init(color: Color.white.opacity(isDockHovered ? 0.32 : 0.22), location: 0.75),
                            .init(color: Color.white.opacity(0.12), location: 0.94),
                            .init(color: Color.white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
        // Upward ambient shadow onto desktop wallpaper
        .shadow(color: Color.black.opacity(isDockHovered ? 0.65 : 0.50), radius: isDockHovered ? 28 : 20, x: 0, y: -4)
        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: -1)
        .scaleEffect(settings.dockScale)
        .onHover { hovering in
            withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                isDockHovered = hovering
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isDockHovered)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.dockScale)
    }
}

private struct SectionDivider: View {
    var body: some View {
        Divider()
            .frame(height: 18)
            .background(Color.white.opacity(0.10))
            .padding(.horizontal, 2)
    }
}
