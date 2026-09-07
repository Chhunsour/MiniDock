import SwiftUI
import AppKit

public struct DockContainerView: View {
    private let displayScale: CGFloat
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var launcher = AppLauncherService.shared
    @ObservedObject private var workspaceService = WorkspaceService.shared
    @ObservedObject private var transient = TransientCapsuleManager.shared
    @State private var isDockHovered = false

    public init(displayScale: CGFloat = 1.0) {
        self.displayScale = displayScale
    }

    public var body: some View {
        let spacing = max(4.0, min(CGFloat(settings.dockSpacing) * 0.5, 8.0))
        let radius = max(14.0, min(CGFloat(settings.cornerRadius), 18.0))
        let flareWidth: CGFloat = 30
        let shape = ScreenAttachedDockShape(
            flareWidth: flareWidth,
            flareHeight: 18,
            cornerRadius: radius
        )

        HStack(spacing: spacing) {
            if settings.showFocus {
                FocusWidgetView()
                DockSeparator()
            }

            if settings.showLauncher {
                AppLauncherWidgetView()
                DockSeparator()
            }

            if settings.showRepo {
                ProjectCapsuleView()
            }

            DevStackWidgetView()
            SecondaryGlanceWidgetView()

            if transient.activeEvent != nil {
                TransientCapsuleView()
            } else if settings.showSystem {
                SystemWidgetView()
            }

            DockSeparator()

            Button(action: {
                CommandPaletteWindowController.shared.toggle()
            }) {
                Image(systemName: "command")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(isDockHovered ? 0.9 : 0.55))
                    .frame(width: 34, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(isDockHovered ? 0.08 : 0))
                    )
            }
            .buttonStyle(.plain)
            .help("FlowDock Command Palette (⌥ Space)")
            .accessibilityLabel("Open Command Palette")
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, flareWidth + 10)
        .padding(.vertical, 8)
        .background { surfaceBackground(shape: shape) }
        .overlay { surfaceBorder(shape: shape) }
        .contentShape(shape)
        .contextMenu {
            dockContextMenu
        }
        .shadow(color: .black.opacity(isDockHovered ? 0.32 : 0.24), radius: isDockHovered ? 14 : 10, y: -2)
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .scaleEffect(displayScale)
        .onHover { hovering in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                isDockHovered = hovering
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: settings.dockSpacing)
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: settings.cornerRadius)
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
                settings.dockBehavior = "Always Visible"
            }) {
                HStack {
                    Text("Always Visible")
                    if settings.dockBehavior == "Always Visible" { Text("✓") }
                }
            }
            Button(action: {
                settings.dockBehavior = "Auto-Hide on Inactive"
            }) {
                HStack {
                    Text("Auto-Hide on Inactive")
                    if settings.dockBehavior == "Auto-Hide on Inactive" { Text("✓") }
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
        case "Obsidian Vantablack":
            shape.fill(Color(red: 0.055, green: 0.055, blue: 0.065).opacity(settings.backgroundOpacity))
        case "System Frost":
            ZStack {
                shape.fill(.regularMaterial)
                shape.fill(.black.opacity(0.12 * settings.backgroundOpacity))
            }
        default:
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(.black.opacity(0.38 * settings.backgroundOpacity))
            }
        }
    }

    @ViewBuilder
    private func surfaceBorder(shape: ScreenAttachedDockShape) -> some View {
        ScreenAttachedDockShape(
            flareWidth: shape.flareWidth,
            flareHeight: shape.flareHeight,
            cornerRadius: shape.cornerRadius,
            isClosed: false
        )
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.18), location: 0.0),
                        .init(color: .white.opacity(0.06), location: 0.35),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.8
            )
            .allowsHitTesting(false)
    }
}

private struct DockSeparator: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(width: 1, height: 24)
            .padding(.horizontal, 1)
    }
}
