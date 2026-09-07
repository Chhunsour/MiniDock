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
            Button(action: {
                AppPickerWindowController.shared.present()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(isAddHovered ? .white : .white.opacity(0.42))
                    .frame(width: 28, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(isAddHovered ? 0.08 : 0))
                    )
            }
            .buttonStyle(.plain)
            .help("Add Application to Dock")
            .accessibilityLabel("Add Application to Dock")
            .onHover { isAddHovered = $0 }

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
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                        .clipShape(RoundedRectangle(cornerRadius: squircleRadius, style: .continuous))
                        .shadow(
                            color: (settings.runningIndicatorStyle == "Glow" && isRunning)
                                ? settings.activeAccentColor.opacity(0.7)
                                : (isHovered && !isEditMode ? Color.black.opacity(0.42) : Color.black.opacity(0.26)),
                            radius: (settings.runningIndicatorStyle == "Glow" && isRunning) ? 5 : (isHovered && !isEditMode ? 6 : 2.5),
                            x: 0,
                            y: (isHovered && !isEditMode ? 3 : 1)
                        )
                        .scaleEffect(isPressed ? 0.94 : (isHovered && !isEditMode ? 1.08 : 1.0))
                        .offset(y: isHovered && !isEditMode ? -2 : 0)
                        .rotationEffect(.degrees(isEditMode ? (wiggle ? 1.6 : -1.6) : 0))
                        .animation(isEditMode ? .easeInOut(duration: 0.14).repeatForever(autoreverses: true) : .spring(response: 0.22, dampingFraction: 0.72), value: isHovered)
                        .animation(.spring(response: 0.18, dampingFraction: 0.70), value: isPressed)
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
        switch settings.runningIndicatorStyle {
        case "Bar":
            Capsule()
                .fill(isRunning ? Color.white.opacity(0.85) : Color.clear)
                .frame(width: 8, height: 2.2)
                .shadow(color: isRunning ? Color.white.opacity(0.35) : Color.clear, radius: 1.5)
        case "Glow":
            Circle()
                .fill(isRunning ? settings.activeAccentColor.opacity(0.8) : Color.clear)
                .frame(width: 3.5, height: 3.5)
                .shadow(color: isRunning ? settings.activeAccentColor.opacity(0.6) : Color.clear, radius: 3)
        case "Off":
            Color.clear.frame(height: 3)
        default: // "Dot"
            Circle()
                .fill(isRunning ? Color.white.opacity(0.85) : Color.clear)
                .frame(width: 3.5, height: 3.5)
                .shadow(color: isRunning ? Color.white.opacity(0.35) : Color.clear, radius: 1.5)
        }
    }

    private func handleTap() {
        if launcherService.isEditMode {
            removeSelf()
        } else {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            launcherService.launch(app)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation {
                    isPressed = false
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
