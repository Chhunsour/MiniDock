import SwiftUI
import AppKit

public enum CommandCategory: String, CaseIterable, Identifiable {
    case action = "Project Actions"
    case workspace = "Workspaces"
    case app = "Applications"
    case project = "Switch Project"
    case flowdock = "FlowDock Commands"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .action: return "bolt.fill"
        case .workspace: return "briefcase.fill"
        case .app: return "app.fill"
        case .project: return "folder.fill"
        case .flowdock: return "flowchart.fill"
        }
    }
}

public struct CommandPaletteItem: Identifiable {
    public let id: String
    public let category: CommandCategory
    public let title: String
    public let subtitle: String?
    public let icon: String
    public let action: @MainActor () -> Void
}

public struct CommandPaletteView: View {
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @ObservedObject private var projectService = ProjectContextService.shared
    @ObservedObject private var workspaceService = WorkspaceService.shared
    @ObservedObject private var launcherService = AppLauncherService.shared
    @ObservedObject private var focusService = FocusService.shared
    
    public let onDismiss: () -> Void
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    private var allCommands: [CommandPaletteItem] {
        var items: [CommandPaletteItem] = []
        
        // 1. Current Project Actions
        let proj = projectService.project
        for act in proj.actions {
            items.append(CommandPaletteItem(
                id: "act_\(act.id)",
                category: .action,
                title: act.title,
                subtitle: "\(proj.name) · \(act.subtitle ?? "")",
                icon: act.icon,
                action: {
                    projectService.executeAction(act)
                    onDismiss()
                }
            ))
        }
        
        // 2. Workspaces
        for ws in workspaceService.workspaces {
            items.append(CommandPaletteItem(
                id: "ws_\(ws.id)",
                category: .workspace,
                title: "Launch \(ws.name)",
                subtitle: ws.projectPath != nil ? URL(fileURLWithPath: ws.projectPath!).lastPathComponent : "Workspace profile",
                icon: ws.icon,
                action: {
                    workspaceService.launchWorkspace(ws)
                    onDismiss()
                }
            ))
        }
        
        // 3. Pinned Apps
        for app in launcherService.apps {
            items.append(CommandPaletteItem(
                id: "app_\(app.id)",
                category: .app,
                title: "Open \(app.name)",
                subtitle: launcherService.isRunning(app) ? "Running" : "Application",
                icon: "arrow.up.right.square",
                action: {
                    launcherService.launch(app)
                    onDismiss()
                }
            ))
        }
        
        // 4. Switch Projects
        for p in projectService.candidateProjects {
            let name = URL(fileURLWithPath: p).lastPathComponent
            if p != proj.path {
                items.append(CommandPaletteItem(
                    id: "proj_\(p)",
                    category: .project,
                    title: "Switch to \(name)",
                    subtitle: p,
                    icon: "folder",
                    action: {
                        projectService.selectProject(at: p)
                        onDismiss()
                    }
                ))
            }
        }
        
        // 5. FlowDock Controls
        items.append(CommandPaletteItem(
            id: "flow_focus_toggle",
            category: .flowdock,
            title: focusService.isRunning ? "Pause Focus Timer" : "Start 25m Focus Sprint",
            subtitle: focusService.statusText,
            icon: focusService.isRunning ? "pause.fill" : "play.fill",
            action: {
                focusService.togglePlayPause()
                onDismiss()
            }
        ))
        
        items.append(CommandPaletteItem(
            id: "flow_settings",
            category: .flowdock,
            title: "FlowDock Settings",
            subtitle: "Preferences, appearance, workspaces",
            icon: "gearshape",
            action: {
                MenuBarController.shared.openSettings()
                onDismiss()
            }
        ))
        
        items.append(CommandPaletteItem(
            id: "flow_recopy",
            category: .flowdock,
            title: "Re-copy Last Clipboard Snippet",
            subtitle: ClipboardService.shared.previewText,
            icon: "doc.on.clipboard",
            action: {
                ClipboardService.shared.copyAgain()
                onDismiss()
            }
        ))
        
        return items
    }
    
    private var filteredCommands: [CommandPaletteItem] {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return allCommands
        }
        let q = query.lowercased()
        return allCommands.filter {
            $0.title.lowercased().contains(q) ||
            ($0.subtitle?.lowercased().contains(q) ?? false) ||
            $0.category.rawValue.lowercased().contains(q)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Header
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("What do you want to do?", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .onChange(of: query) { _, _ in
                        selectedIndex = 0
                    }
                
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                
                Text("ESC to close")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08)))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            
            Divider().background(Color.white.opacity(0.12))
            
            // Results List
            if filteredCommands.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.folder")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No matching commands found")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, item in
                                CommandRowView(
                                    item: item,
                                    isSelected: index == selectedIndex,
                                    onSelect: {
                                        item.action()
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 360)
                }
            }
            
            Divider().background(Color.white.opacity(0.12))
            
            // Footer Hint Bar
            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.and.down")
                    Text("Navigate")
                }
                HStack(spacing: 5) {
                    Image(systemName: "return")
                    Text("Execute")
                }
                Spacer()
                Text("FlowDock Command Center")
                    .foregroundColor(.white.opacity(0.4))
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 580)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.11).opacity(0.94))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(0.6), radius: 35, x: 0, y: 15)
        .onAppear {
            selectedIndex = 0
        }
        .background(
            // Hidden key listener for arrow navigation & execution
            CommandKeyHandler(
                onUp: {
                    if selectedIndex > 0 { selectedIndex -= 1 }
                },
                onDown: {
                    if selectedIndex < filteredCommands.count - 1 { selectedIndex += 1 }
                },
                onEnter: {
                    if filteredCommands.indices.contains(selectedIndex) {
                        filteredCommands[selectedIndex].action()
                    }
                },
                onEscape: {
                    onDismiss()
                }
            )
        )
    }
}

private struct CommandRowView: View {
    let item: CommandPaletteItem
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Category Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.blue : Color.white.opacity(0.08))
                        .frame(width: 26, height: 26)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let sub = item.subtitle {
                        Text(sub)
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Text(item.category.rawValue)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.35))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CommandKeyHandler: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onEnter: () -> Void
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onUp = onUp
        view.onDown = onDown
        view.onEnter = onEnter
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onUp = onUp
        nsView.onDown = onDown
        nsView.onEnter = onEnter
        nsView.onEscape = onEscape
    }
    
    class KeyView: NSView {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onEnter: (() -> Void)?
        var onEscape: (() -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 126: // Up arrow
                onUp?()
            case 125: // Down arrow
                onDown?()
            case 36: // Enter
                onEnter?()
            case 53: // Escape
                onEscape?()
            default:
                super.keyDown(with: event)
            }
        }
    }
}
