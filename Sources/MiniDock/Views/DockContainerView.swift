import SwiftUI
import AppKit

public struct DockContainerView: View {
    private let displayScale: CGFloat
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var launcher = AppLauncherService.shared
    @ObservedObject private var workspaceService = WorkspaceService.shared
    @ObservedObject private var transient = TransientCapsuleManager.shared
    @State private var isDockHovered = false
    @State private var isCommandHovered = false

    public init(displayScale: CGFloat = 1.0) {
        self.displayScale = displayScale
    }

    private var isLiquidGlass: Bool {
        settings.isGlassLike
    }

    public var body: some View {
        let spacing = isLiquidGlass
            ? max(6.0, min(CGFloat(settings.dockSpacing) * 0.65, 11.0))
            : max(4.0, min(CGFloat(settings.dockSpacing) * 0.5, 8.0))
        let radius = isLiquidGlass
            ? max(18.0, min(CGFloat(settings.cornerRadius) + 2.0, 22.0))
            : max(14.0, min(CGFloat(settings.cornerRadius), 18.0))
        let flareWidth: CGFloat = isLiquidGlass ? 0 : 30
        let attachedShape = ScreenAttachedDockShape(
            flareWidth: flareWidth,
            flareHeight: 18,
            cornerRadius: radius
        )
        let gluedShape = UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: radius,
            style: .continuous
        )

        HStack(spacing: spacing) {
            if settings.showFocus {
                FocusWidgetView()
                DockSeparator(isLiquidGlass: isLiquidGlass, isHovered: isDockHovered)
            }

            if settings.showLauncher {
                AppLauncherWidgetView()
                DockSeparator(isLiquidGlass: isLiquidGlass, isHovered: isDockHovered)
            }

            DevStackWidgetView()
            SecondaryGlanceWidgetView()

            if transient.activeEvent != nil {
                TransientCapsuleView()
            } else if settings.showSystem {
                SystemWidgetView()
            }

            DockSeparator(isLiquidGlass: isLiquidGlass, isHovered: isDockHovered)

            WidgetCardView(onHoverChanged: { isCommandHovered = $0 }) {
                Button(action: {
                    CommandPaletteWindowController.shared.toggle()
                }) {
                    Image(systemName: "command")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(isCommandHovered ? .white : .white.opacity(0.85))
                        .scaleEffect(isCommandHovered ? 1.14 : 1.0)
                        .shadow(color: Color.white.opacity(isCommandHovered ? 0.45 : 0), radius: 2.5)
                        .animation(.spring(response: 0.20, dampingFraction: 0.72), value: isCommandHovered)
                        .frame(width: 20, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("FlowDock Command Palette (⌥ Space)")
                .accessibilityLabel("Open Command Palette")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, isLiquidGlass ? 14 : (flareWidth + 10))
        .padding(.top, isLiquidGlass ? 6 : 8)
        .padding(.bottom, isLiquidGlass ? 4 : 8)
        .background {
            if isLiquidGlass {
                liquidGlassBackground(shape: gluedShape)
            } else {
                surfaceBackground(shape: attachedShape)
            }
        }
        .overlay {
            if isLiquidGlass {
                liquidGlassBorder(shape: gluedShape)
            } else {
                surfaceBorder(shape: attachedShape)
            }
        }
        .clipShape(isLiquidGlass ? AnyShape(gluedShape) : AnyShape(attachedShape))
        .contextMenu {
            dockContextMenu
        }
        .shadow(
            color: settings.materialStyle == "Fully Transparent"
                ? Color.clear
                : Color.black.opacity(isDockHovered ? 0.45 : 0.35),
            radius: isDockHovered ? 8 : 5,
            x: 0,
            y: isDockHovered ? -3 : -2
        )
        .shadow(
            color: settings.materialStyle == "Fully Transparent"
                ? Color.clear
                : Color.black.opacity(isDockHovered ? 0.32 : 0.22),
            radius: isDockHovered ? 24 : 16,
            x: 0,
            y: isDockHovered ? -7 : -5
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .scaleEffect(displayScale)
        .onHover { hovering in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                isDockHovered = hovering
            }
            if hovering {
                MiniDockPanel.shared?.cancelPendingHide()
            } else if settings.dockBehavior != "Always Visible" {
                MiniDockPanel.shared?.scheduleHideDock(delay: 0.35)
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: settings.dockSpacing)
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: settings.cornerRadius)
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: settings.materialStyle)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // ESC
                    if AppLauncherService.shared.isEditMode {
                        Task { @MainActor in
                            withAnimation {
                                AppLauncherService.shared.isEditMode = false
                            }
                        }
                        return nil
                    }
                }
                return event
            }
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    if AppLauncherService.shared.isEditMode {
                        Task { @MainActor in
                            withAnimation {
                                AppLauncherService.shared.isEditMode = false
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func liquidGlassBackground(shape: UnevenRoundedRectangle) -> some View {
        if settings.materialStyle == "Fully Transparent" {
            ZStack {
                // Completely transparent background
                shape.fill(Color.clear)

                // Ultra-delicate breath of glass presence on hover
                if isDockHovered {
                    shape.fill(Color.white.opacity(0.04))
                }
            }
        } else {
            ZStack {
                // 1. Deep frosted Apple optical blur
                shape.fill(.ultraThinMaterial)

                // 2. Foundation Color Gradient
                if settings.materialStyle == "Liquid Glass" {
                    shape.fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.12, green: 0.14, blue: 0.20).opacity(0.42), location: 0.0),
                                .init(color: Color(red: 0.06, green: 0.07, blue: 0.11).opacity(0.48), location: 0.35),
                                .init(color: Color(red: 0.02, green: 0.025, blue: 0.04).opacity(0.55), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                } else if settings.materialStyle == "Obsidian Vantablack" {
                    shape.fill(Color(red: 0.008, green: 0.008, blue: 0.010).opacity(0.99))
                } else {
                    // Pure Inky Obsidian Black Foundation (Deep OLED Pitch Black)
                    shape.fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.04, green: 0.04, blue: 0.045).opacity(0.96), location: 0.0),
                                .init(color: Color(red: 0.018, green: 0.018, blue: 0.022).opacity(0.98), location: 0.35),
                                .init(color: Color(red: 0.005, green: 0.005, blue: 0.008).opacity(0.99), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // 3. Top Specular Obsidian Sheen (Polished glass reflection across top squircle curve)
                VStack {
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(isDockHovered ? 0.48 : (settings.materialStyle == "Liquid Glass" ? 0.46 : 0.40)), location: 0.0),
                            .init(color: Color.white.opacity(isDockHovered ? 0.16 : (settings.materialStyle == "Liquid Glass" ? 0.14 : 0.12)), location: 0.16),
                            .init(color: Color.clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 18)
                    .clipShape(shape)
                    Spacer()
                }
                .allowsHitTesting(false)
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isDockHovered)
            }
        }
    }

    @ViewBuilder
    private func liquidGlassBorder(shape: UnevenRoundedRectangle) -> some View {
        if settings.materialStyle == "Fully Transparent" {
            // Delicate glass shimmer only on top shoulder when hovered, no heavy dark borders
            shape
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(isDockHovered ? 0.24 : 0.08), location: 0.0),
                            .init(color: Color.white.opacity(isDockHovered ? 0.08 : 0.02), location: 0.35),
                            .init(color: Color.clear, location: 0.80)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
                .allowsHitTesting(false)
        } else {
            ZStack {
                // Outer obsidian edge definition (fades before reaching bottom bezel)
                shape
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.90), location: 0.0),
                                .init(color: Color.black.opacity(0.50), location: 0.60),
                                .init(color: Color.clear, location: 0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.65
                    )

                // Inner specular rim highlight (polished obsidian glass reflection on top crest & shoulders)
                shape
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.65), location: 0.0),
                                .init(color: Color.white.opacity(0.24), location: 0.25),
                                .init(color: Color.white.opacity(0.04), location: 0.60),
                                .init(color: Color.clear, location: 0.90)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var dockContextMenu: some View {
        Text("FlowDock").font(.headline)
        Divider()

        Button("Add Application...") {
            AppPickerWindowController.shared.present()
        }

        Button(action: {
            withAnimation {
                launcher.isEditMode.toggle()
            }
        }) {
            HStack {
                Text("Edit Apps")
                if launcher.isEditMode {
                    Text("✓")
                }
            }
        }

        Menu("Workspaces") {
            ForEach(workspaceService.workspaces) { ws in
                Button(ws.name) {
                    workspaceService.launchWorkspace(ws)
                }
            }
            Divider()
            Button("Manage Workspaces...") {
                MenuBarController.shared.openSettings(tab: .workspaces)
            }
        }

        Menu("Focus") {
            Button("Start 25m Focus") {
                FocusService.shared.switchMode(.focus25)
                FocusService.shared.start()
            }
            Button("Start 50m Deep Work") {
                FocusService.shared.switchMode(.focus50)
                FocusService.shared.start()
            }
            Button("Start 90m Flow State") {
                FocusService.shared.switchMode(.focus90)
                FocusService.shared.start()
            }
            Button("5m Short Break") {
                FocusService.shared.switchMode(.shortBreak)
                FocusService.shared.start()
            }
            Button("15m Long Break") {
                FocusService.shared.switchMode(.longBreak)
                FocusService.shared.start()
            }
            Divider()
            Button(FocusService.shared.isRunning ? "Pause Focus" : "Resume Focus") {
                FocusService.shared.togglePlayPause()
            }
            .disabled(!FocusService.shared.isRunning && !FocusService.shared.isPaused)
            Button("Reset Focus") {
                FocusService.shared.reset()
            }
            Divider()
            Button("Focus Settings...") {
                MenuBarController.shared.openSettings(tab: .focus)
            }
        }

        Divider()

        Menu("Dock Position") {
            Button("Bottom ✓") {}
            Button("Left (Coming Soon)") {}.disabled(true)
            Button("Right (Coming Soon)") {}.disabled(true)
        }

        Menu("Auto Hide") {
            Button(action: {
                settings.dockBehavior = "Auto-Hide (macOS Dock)"
            }) {
                HStack {
                    Text("Auto-Hide (macOS Dock)")
                    if settings.dockBehavior == "Auto-Hide (macOS Dock)" { Text("✓") }
                }
            }
            Button(action: {
                settings.dockBehavior = "Auto-Hide on Window Overlap"
            }) {
                HStack {
                    Text("Auto-Hide on Window Overlap (Intellihide)")
                    if settings.dockBehavior == "Auto-Hide on Window Overlap" { Text("✓") }
                }
            }
            Button(action: {
                settings.dockBehavior = "Always Visible"
            }) {
                HStack {
                    Text("Always Visible")
                    if settings.dockBehavior == "Always Visible" { Text("✓") }
                }
            }
            Divider()
            Button(action: {
                settings.autoHideAppleDock.toggle()
                DockManager.shared.setAppleDockAutoHide(settings.autoHideAppleDock)
            }) {
                HStack {
                    Text("Auto-Hide Apple Dock")
                    if settings.autoHideAppleDock { Text("✓") }
                }
            }
        }

        Menu("Appearance") {
            Button(action: {
                settings.materialStyle = "Fully Transparent"
            }) {
                HStack {
                    Text("Fully Transparent ✨")
                    if settings.materialStyle == "Fully Transparent" { Text("✓") }
                }
            }
            Button(action: {
                settings.materialStyle = "Obsidian Black"
            }) {
                HStack {
                    Text("Obsidian Black")
                    if settings.materialStyle == "Obsidian Black" { Text("✓") }
                }
            }
            Button(action: {
                settings.materialStyle = "Liquid Glass"
            }) {
                HStack {
                    Text("Liquid Glass")
                    if settings.materialStyle == "Liquid Glass" { Text("✓") }
                }
            }
            Button(action: {
                settings.materialStyle = "System Frost"
            }) {
                HStack {
                    Text("System Frost")
                    if settings.materialStyle == "System Frost" { Text("✓") }
                }
            }
        }

        Menu("Apps & Dock Items") {
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

            Divider()

            Button("Add Application...") {
                AppPickerWindowController.shared.present()
            }

            Button(AppLauncherService.shared.isEditMode ? "Done Editing Apps" : "Edit Pinned Apps") {
                withAnimation {
                    AppLauncherService.shared.isEditMode.toggle()
                }
            }
        }

        Divider()

        Button("Settings...") {
            MenuBarController.shared.openSettings(tab: .general)
        }

        Divider()

        Button("Restart FlowDock") {
            MenuBarController.shared.restartFlowDock()
        }

        Button("Quit FlowDock") {
            MenuBarController.shared.quitApp()
        }
    }

    @ViewBuilder
    private func surfaceBackground(shape: ScreenAttachedDockShape) -> some View {
        switch settings.materialStyle {
        case "Fully Transparent":
            shape.fill(Color.clear)
        case "System Frost":
            ZStack {
                shape.fill(.regularMaterial)
                shape.fill(Color.black)

                // Subtle top hairline glint across the curved shoulders
                VStack {
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(isDockHovered ? 0.32 : 0.20), location: 0.0),
                            .init(color: Color.white.opacity(isDockHovered ? 0.10 : 0.05), location: 0.25),
                            .init(color: Color.clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 16)
                    .clipShape(shape)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        case "Obsidian Vantablack":
            shape.fill(Color.black)
        default:
            ZStack {
                shape.fill(.regularMaterial)
                shape.fill(Color.black)
            }
        }
    }

    @ViewBuilder
    private func surfaceBorder(shape: ScreenAttachedDockShape) -> some View {
        if settings.materialStyle == "Fully Transparent" {
            ScreenAttachedDockShape(
                flareWidth: shape.flareWidth,
                flareHeight: shape.flareHeight,
                cornerRadius: shape.cornerRadius,
                isClosed: false
            )
            .stroke(
                Color.white.opacity(isDockHovered ? 0.20 : 0.08),
                lineWidth: 0.75
            )
            .allowsHitTesting(false)
        } else {
            ScreenAttachedDockShape(
                flareWidth: shape.flareWidth,
                flareHeight: shape.flareHeight,
                cornerRadius: shape.cornerRadius,
                isClosed: false
            )
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(isDockHovered ? 0.32 : 0.22), location: 0.0),
                        .init(color: .white.opacity(isDockHovered ? 0.12 : 0.07), location: 0.35),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.85
            )
            .allowsHitTesting(false)
        }
    }
}

private struct DockSeparator: View {
    var isLiquidGlass: Bool = true
    var isHovered: Bool = false

    var body: some View {
        if isLiquidGlass {
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(isHovered ? 0.32 : 0.20), location: 0.25),
                            .init(color: Color.white.opacity(isHovered ? 0.32 : 0.20), location: 0.75),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1, height: 20)
                .padding(.horizontal, 2)
                .animation(.spring(response: 0.24, dampingFraction: 0.80), value: isHovered)
        } else {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 1)
        }
    }
}
