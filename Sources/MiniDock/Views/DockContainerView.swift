import SwiftUI
import AppKit

public struct DockContainerView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var launcher = AppLauncherService.shared
    @ObservedObject private var workspaceService = WorkspaceService.shared
    @ObservedObject private var transient = TransientCapsuleManager.shared
    @State private var isDockHovered = false
    
    public init() {}
    
    public var body: some View {
        let flareWidth = CGFloat(settings.flareWidth)
        let dockSpacing = CGFloat(settings.dockSpacing) + (isDockHovered ? 2 : 0)
        let radius = CGFloat(settings.cornerRadius)
        let sideClearance = max(flareWidth + 12, 46)
        
        HStack(spacing: dockSpacing) {
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
        .padding(.horizontal, sideClearance) // Generous clearance for sculpted organic bezier shoulders
        .padding(.top, isDockHovered ? 9 : 8)
        .padding(.bottom, isDockHovered ? 7 : 6)
        .background(
            ZStack {
                // Glass material layer
                switch settings.materialStyle {
                case "Obsidian Vantablack":
                    EdgeFusedDockShape(flareWidth: flareWidth, cornerRadius: radius)
                        .fill(Color(red: 0.03, green: 0.03, blue: 0.04))
                case "System Frost":
                    EdgeFusedDockShape(flareWidth: flareWidth, cornerRadius: radius)
                        .fill(.regularMaterial)
                default: // "Dark Glass"
                    EdgeFusedDockShape(flareWidth: flareWidth, cornerRadius: radius)
                        .fill(.ultraThinMaterial)
                }
                
                // Deep obsidian gradient fading smoothly into bottom monitor bezel
                EdgeFusedDockShape(flareWidth: flareWidth, cornerRadius: radius)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.12, green: 0.12, blue: 0.15).opacity(settings.backgroundOpacity * 0.95), location: 0.0),
                                .init(color: Color(red: 0.06, green: 0.06, blue: 0.08).opacity(settings.backgroundOpacity), location: 0.40),
                                .init(color: Color(red: 0.01, green: 0.01, blue: 0.02).opacity(min(settings.backgroundOpacity + 0.08, 1.0)), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Subtle inner ambient highlight along the crest
                EdgeFusedDockShape(flareWidth: flareWidth, cornerRadius: radius)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(isDockHovered ? 0.08 : 0.04), location: 0.0),
                                .init(color: Color.white.opacity(0.0), location: 0.40)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .contentShape(EdgeFusedDockShape(flareWidth: flareWidth, cornerRadius: radius))
            .contextMenu {
                dockContextMenu
            }
        )
        .overlay(
            // Hairline specular crest highlight that vanishes at the shoulders
            EdgeFusedDockRim(flareWidth: flareWidth, cornerRadius: radius)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.0), location: 0.0),
                            .init(color: Color.white.opacity(isDockHovered ? 0.28 : 0.18), location: 0.15),
                            .init(color: Color.white.opacity(isDockHovered ? 0.40 : 0.28), location: 0.50),
                            .init(color: Color.white.opacity(isDockHovered ? 0.28 : 0.18), location: 0.85),
                            .init(color: Color.white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
        // Restrained ambient elevation shadows
        .shadow(color: Color.black.opacity(isDockHovered ? 0.55 : 0.40), radius: isDockHovered ? 26 : 18, x: 0, y: -4)
        .shadow(color: Color.black.opacity(0.20), radius: 6, x: 0, y: -1)
        // Subtle accent rim reflection only if enabled
        .shadow(color: settings.activeAccentColor.opacity(settings.subtleGlowAmount * 0.7), radius: isDockHovered ? 16 : 10, x: 0, y: -2)
        .scaleEffect(settings.dockScale)
        .onHover { hovering in
            withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                isDockHovered = hovering
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isDockHovered)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: settings.dockScale)
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: settings.dockSpacing)
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: settings.cornerRadius)
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: settings.flareWidth)
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
}

private struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 3)
    }
}
