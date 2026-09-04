import SwiftUI
import AppKit

public struct AppLauncherWidgetView: View {
    @ObservedObject private var launcherService = AppLauncherService.shared
    @State private var isAddHovered = false
    
    public init() {}
    
    public var body: some View {
        let displayedApps = launcherService.isEditMode ? launcherService.apps : launcherService.visibleApps
        
        WidgetCardView {
            HStack(spacing: launcherService.isEditMode ? 10 : 11) {
                ForEach(displayedApps) { app in
                    AppIconSlotView(app: app)
                }
                
                // Inline Add Button
                Button(action: {
                    AppPickerWindowController.shared.present()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isAddHovered ? .white : .white.opacity(0.45))
                        .frame(width: 20, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(isAddHovered ? 0.14 : 0.04))
                        )
                }
                .buttonStyle(.plain)
                .help("Add Application to Dock")
                .onHover { isAddHovered = $0 }
                
                if launcherService.isEditMode {
                    Button(action: {
                        withAnimation {
                            launcherService.isEditMode = false
                        }
                    }) {
                        Text("Done")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
        
        ZStack(alignment: .topTrailing) {
            Button(action: handleTap) {
                VStack(spacing: 3) {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                        .cornerRadius(max(iconSize * 0.22, 5))
                        .shadow(
                            color: (settings.runningIndicatorStyle == "Glow" && isRunning) ? settings.activeAccentColor.opacity(0.8) : (isHovered ? Color.white.opacity(0.35) : Color.black.opacity(0.3)),
                            radius: (settings.runningIndicatorStyle == "Glow" && isRunning) ? 6 : (isHovered ? 5 : 2),
                            x: 0,
                            y: 1
                        )
                        .scaleEffect(isPressed ? 0.90 : (isHovered && !isEditMode ? 1.15 : 1.0))
                        .rotationEffect(.degrees(isEditMode ? (wiggle ? 1.8 : -1.8) : 0))
                        .animation(isEditMode ? .easeInOut(duration: 0.14).repeatForever(autoreverses: true) : .default, value: wiggle)
                        .onAppear {
                            if isEditMode { wiggle = true }
                        }
                        .onChange(of: isEditMode) { _, active in
                            wiggle = active
                        }
                    
                    // Active Running Indicator
                    indicatorView(isRunning: isRunning)
                }
                .frame(width: max(iconSize, 32), height: iconSize + 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(app.name)
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
                .fill(isRunning ? Color.white.opacity(0.9) : Color.clear)
                .frame(width: 12, height: 2.5)
                .shadow(color: isRunning ? Color.white.opacity(0.6) : Color.clear, radius: 2)
        case "Glow":
            Color.clear.frame(height: 3)
        case "Off":
            Color.clear.frame(height: 3)
        default: // "Dot"
            Circle()
                .fill(isRunning ? Color.white.opacity(0.9) : Color.clear)
                .frame(width: 3.5, height: 3.5)
                .shadow(color: isRunning ? Color.white.opacity(0.6) : Color.clear, radius: 2)
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
