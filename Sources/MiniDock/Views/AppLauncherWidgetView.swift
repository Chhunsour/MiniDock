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
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    
    var body: some View {
        let isRunning = launcherService.isRunning(app)
        let isEditMode = launcherService.isEditMode
        let icon = app.icon
        
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 3) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
                    .shadow(color: isHovered ? Color.white.opacity(0.35) : Color.black.opacity(0.3), radius: isHovered ? 5 : 2, x: 0, y: 1)
                    .scaleEffect(isPressed ? 0.90 : (isHovered && !isEditMode ? 1.15 : 1.0))
                
                // Active Running Indicator Dot
                Circle()
                    .fill(isRunning ? Color.white.opacity(0.9) : Color.clear)
                    .frame(width: 3.5, height: 3.5)
                    .shadow(color: isRunning ? Color.white.opacity(0.6) : Color.clear, radius: 2)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
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
        .help(app.name)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Open") {
                handleTap()
            }
            
            Button("Show in Finder") {
                launcherService.showInFinder(app)
            }
            
            Button("Replace Application...") {
                AppPickerWindowController.shared.present(replacingItem: app)
            }
            
            Button("Remove from Dock") {
                removeSelf()
            }
            
            if isRunning && app.bundleIdentifier != "com.apple.finder" {
                Divider()
                Button("Quit \(app.name)") {
                    launcherService.quitApp(app)
                }
            }
            
            Divider()
            
            Button("Add Application...") {
                AppPickerWindowController.shared.present()
            }
            
            Button(isEditMode ? "Done Editing" : "Edit Apps") {
                withAnimation {
                    launcherService.isEditMode.toggle()
                }
            }
            
            Divider()
            
            Button("MiniDock Settings...") {
                NotificationCenter.default.post(name: NSNotification.Name("OpenMiniDockSettings"), object: nil)
            }
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
