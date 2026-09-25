import SwiftUI
import AppKit

public struct AppLauncherWidgetView: View {
    @ObservedObject private var launcherService = AppLauncherService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var isAddHovered = false

    public init() {}

    public var body: some View {
        let displayedApps = launcherService.isEditMode ? launcherService.apps : launcherService.visibleApps
        let iconSpacing = max(4.0, min(CGFloat(settings.dockSpacing) * 0.5, 8.0))

        HStack(spacing: launcherService.isEditMode ? max(iconSpacing, 8) : iconSpacing) {
            ForEach(displayedApps) { app in
                AppIconSlotView(app: app)
            }

            // Inline Add Button
            if settings.showAddAppButton || launcherService.isEditMode {
                Button(action: {
                    AppPickerWindowController.shared.present()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(isAddHovered ? 0.10 : 0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            stops: [
                                                .init(color: Color.white.opacity(isAddHovered ? 0.32 : 0.12), location: 0.0),
                                                .init(color: Color.white.opacity(isAddHovered ? 0.12 : 0.03), location: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.6
                                    )
                            )
                            .frame(width: 22, height: 26)

                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isAddHovered ? .white : .white.opacity(0.48))
                    }
                    .frame(width: 26, height: 38)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Add Application to Dock")
                .accessibilityLabel("Add Application to Dock")
                .onHover { isAddHovered = $0 }
                .contextMenu {
                    Button("Hide '+' Add Button") {
                        settings.showAddAppButton = false
                    }
                    Button("Add Application...") {
                        AppPickerWindowController.shared.present()
                    }
                }
            }

            if launcherService.isEditMode {
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        launcherService.isEditMode = false
                    }
                }) {
                    Text("Done")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 3, y: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Done Editing Dock")
                .accessibilityLabel("Done Editing Dock")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct AppIconSlotView: View {
    let app: LauncherAppItem
    @ObservedObject private var launcherService = AppLauncherService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    @State private var bounceOffset: CGFloat = 0.0
    @State private var wiggle: Bool = false

    var body: some View {
        let isRunning = launcherService.isRunning(app)
        let isEditMode = launcherService.isEditMode
        let icon = app.icon
        let iconSize = CGFloat(settings.iconSize)
        let squircleRadius = max(iconSize * 0.2237, 6)

        ZStack(alignment: .topTrailing) {
            Button(action: handleTap) {
                VStack(spacing: 3) {
                    ZStack {
                        if (isHovered || bounceOffset < -1) && !isEditMode && settings.isGlassLike {
                            Ellipse()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(isHovered ? 0.42 : 0.22),
                                            Color.white.opacity(isHovered ? 0.14 : 0.06),
                                            Color.white.opacity(0.0)
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: iconSize * 0.72
                                    )
                                )
                                .frame(width: iconSize * 1.30, height: 8)
                                .offset(y: iconSize * 0.46)
                                .blur(radius: 2.8)
                        }

                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: squircleRadius, style: .continuous))
                            .shadow(
                                color: (settings.showRunningIndicators && settings.runningIndicatorStyle == "Glow" && isRunning)
                                    ? settings.activeAccentColor.opacity(0.7)
                                    : (isHovered && !isEditMode ? Color.black.opacity(0.50) : Color.black.opacity(0.24)),
                                radius: (settings.showRunningIndicators && settings.runningIndicatorStyle == "Glow" && isRunning) ? 5 : (isHovered && !isEditMode ? 9 : 2.5),
                                x: 0,
                                y: (isHovered && !isEditMode ? 5.0 : 1)
                            )
                            .scaleEffect(isPressed ? 0.88 : (isHovered && !isEditMode ? 1.15 : 1.0))
                            .offset(y: (isHovered && !isEditMode ? -4.5 : 0) + bounceOffset)
                            .rotationEffect(.degrees(isEditMode ? (wiggle ? 1.6 : -1.6) : 0))
                            .animation(isEditMode ? .easeInOut(duration: 0.14).repeatForever(autoreverses: true) : .spring(response: 0.22, dampingFraction: 0.68), value: isHovered)
                            .animation(.spring(response: 0.16, dampingFraction: 0.70), value: isPressed)
                    }
                    .onAppear {
                        if isEditMode { wiggle = true }
                    }
                    .onChange(of: isEditMode) { _, active in
                        wiggle = active
                    }

                    // Whisper-Quiet Running Indicator
                    indicatorView(isRunning: isRunning)
                }
                .frame(width: max(iconSize + 2, 32), height: iconSize + 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(app.name)
            .accessibilityLabel("\(app.name)\(isRunning ? ", running" : "")")
            .accessibilityHint(isEditMode ? "Click to remove from dock" : "Click to open or activate application")
            .onHover { hovering in
                isHovered = hovering
            }
            .contentShape(Rectangle())
            .contextMenu {
                Text(app.name).font(.headline)
                Divider()

                Button("Open / Focus") {
                    handleTap()
                }

                Button("New Window") {
                    launcherService.openNewWindow(app)
                }

                Button("Show in Finder") {
                    launcherService.showInFinder(app)
                }

                if isRunning {
                    Button("Hide") {
                        launcherService.hideApp(app)
                    }

                    if app.bundleIdentifier != "com.apple.finder" {
                        Button("Quit") {
                            launcherService.quitApp(app)
                        }
                    }
                }

                Divider()

                Menu("Dock Display Options") {
                    Button(action: {
                        let current = settings.showRunningIndicators && settings.runningIndicatorStyle != "Off"
                        let next = !current
                        settings.showRunningIndicators = next
                        if next && settings.runningIndicatorStyle == "Off" {
                            settings.runningIndicatorStyle = "Dot"
                        } else if !next {
                            settings.runningIndicatorStyle = "Off"
                        }
                    }) {
                        HStack {
                            Text("Show Running Indicators (Dots)")
                            if settings.showRunningIndicators && settings.runningIndicatorStyle != "Off" { Text("✓") }
                        }
                    }

                    Button(action: {
                        settings.showAddAppButton.toggle()
                    }) {
                        HStack {
                            Text("Show '+' Add Button")
                            if settings.showAddAppButton { Text("✓") }
                        }
                    }

                    Button(action: {
                        settings.showOnlyRunningApps.toggle()
                    }) {
                        HStack {
                            Text("Show Only Running Apps")
                            if settings.showOnlyRunningApps { Text("✓") }
                        }
                    }
                }

                Divider()

                Button("Remove from FlowDock") {
                    removeSelf()
                }

                Button("Replace Application...") {
                    AppPickerWindowController.shared.present(replacingItem: app)
                }

                Divider()

                Button("FlowDock Settings...") {
                    MenuBarController.shared.openSettings(tab: .apps)
                }
            }

            // Circular × Remove Badge in Edit Mode
            if isEditMode {
                Button(action: removeSelf) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white).frame(width: 10, height: 10))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -4)
            }
        }
    }

    @ViewBuilder
    private func indicatorView(isRunning: Bool) -> some View {
        if !settings.showRunningIndicators || settings.runningIndicatorStyle == "Off" {
            Color.clear.frame(height: 3)
        } else {
            switch settings.runningIndicatorStyle {
            case "Bar":
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isRunning ? 0.95 : 0), Color.white.opacity(isRunning ? 0.70 : 0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8, height: 2.2)
                    .shadow(color: isRunning ? Color.white.opacity(0.40) : Color.clear, radius: 2)
            case "Glow":
                Circle()
                    .fill(isRunning ? settings.activeAccentColor.opacity(0.9) : Color.clear)
                    .frame(width: 3.5, height: 3.5)
                    .shadow(color: isRunning ? settings.activeAccentColor.opacity(0.7) : Color.clear, radius: 3)
            default: // "Dot"
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isRunning ? 0.95 : 0),
                                Color.white.opacity(isRunning ? 0.75 : 0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                .frame(width: isRunning ? (isHovered ? 5.5 : 4) : 0, height: 2.6)
                .shadow(color: isRunning ? Color.white.opacity(0.45) : Color.clear, radius: 2)
                .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isHovered)
            }
        }
    }

    private func handleTap() {
        if launcherService.isEditMode {
            removeSelf()
        } else {
            // Tactile press & initial spring
            withAnimation(.spring(response: 0.16, dampingFraction: 0.65)) {
                isPressed = true
            }
            launcherService.launch(app)

            // Dynamic macOS Launch Bounce Sequence
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                    isPressed = false
                    bounceOffset = -13.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.60)) {
                        bounceOffset = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.20, dampingFraction: 0.65)) {
                            bounceOffset = -5.5
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                                bounceOffset = 0.0
                            }
                        }
                    }
                }
            }
        }
    }

    private func removeSelf() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            launcherService.removeApp(id: app.id)
        }
    }
}
