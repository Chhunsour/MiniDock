import SwiftUI
import AppKit

public struct ProjectCapsuleView: View {
    @ObservedObject private var service = ProjectContextService.shared
    @State private var showingDetailPopover = false
    @State private var isHovered = false

    public init() {}

    public var body: some View {
        let p = service.project

        Button(action: {
            showingDetailPopover.toggle()
        }) {
            HStack(spacing: 7) {
                // Stack or folder icon (neutral restrained aesthetic)
                ZStack {
                    Image(systemName: p.primaryStack.icon)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(isHovered ? .white : .white.opacity(0.68))
                }
                .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 4) {
                        Text(p.name)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if p.isClean {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color.green.opacity(0.85))
                        } else {
                            Text("+\(p.gitDirtyCount)")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.orange.opacity(0.90))
                                .monospacedDigit()
                        }
                    }

                    HStack(spacing: 3) {
                        Text(p.gitBranch)
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.50))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if p.gitAheadCount > 0 {
                            Text("↑\(p.gitAheadCount)")
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundColor(Color.cyan.opacity(0.85))
                                .monospacedDigit()
                        }

                        if p.gitBehindCount > 0 {
                            Text("↓\(p.gitBehindCount)")
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundColor(Color.orange.opacity(0.85))
                                .monospacedDigit()
                        }
                    }
                }
                .frame(width: 116, alignment: .leading)
            }
            .frame(height: 40)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.0))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Current Project: \(p.name) (\(p.gitBranch)) · Click for Actions")
        .popover(isPresented: $showingDetailPopover, arrowEdge: .top) {
            ProjectDetailPanel(service: service)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Text("Project: \(p.name)").font(.headline)
            Divider()

            Button("Open in Editor") {
                service.openInBestEditor(path: p.path)
            }

            Button("Open Terminal") {
                service.openTerminal(at: p.path)
            }

            Button("Open Folder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: p.path)
            }

            if let gh = p.gitHubURL {
                Button("View on GitHub") {
                    NSWorkspace.shared.open(gh)
                }
            }

            if !p.actions.isEmpty {
                Divider()
                Menu("Quick Actions") {
                    ForEach(p.actions) { action in
                        Button(action.title) {
                            service.executeAction(action)
                        }
                    }
                }
            }

            if !service.candidateProjects.isEmpty {
                Menu("Switch Project") {
                    ForEach(service.candidateProjects, id: \.self) { path in
                        Button(action: {
                            service.selectProject(at: path)
                        }) {
                            HStack {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                if path == p.path {
                                    Text("✓")
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Project Settings...") {
                MenuBarController.shared.openSettings(tab: .projects)
            }

            Button("FlowDock Settings...") {
                MenuBarController.shared.openSettings(tab: .general)
            }
        }
    }
}

private struct ProjectDetailPanel: View {
    @ObservedObject var service: ProjectContextService
    @ObservedObject var devStack = DevStackService.shared

    var body: some View {
        let p = service.project

        VStack(alignment: .leading, spacing: 12) {
            // Header: Project Name & Stack badge
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(p.path)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()

                ForEach(p.stackTypes.prefix(2)) { stack in
                    Text(stack.rawValue)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.blue.opacity(0.18)))
                        .foregroundColor(.blue)
                }
            }

            Divider().background(Color.white.opacity(0.12))

            // Git Context Rows
            HStack(spacing: 12) {
                GitBadgeView(label: "Branch", value: p.gitBranch, icon: "arrow.triangle.branch", color: .blue)
                GitBadgeView(
                    label: "Working Tree",
                    value: p.isClean ? "Clean" : "\(p.gitDirtyCount) modified",
                    icon: p.isClean ? "checkmark.circle.fill" : "pencil.circle.fill",
                    color: p.isClean ? .green : .orange
                )
                if p.gitAheadCount > 0 || p.gitBehindCount > 0 {
                    GitBadgeView(
                        label: "Sync",
                        value: "↑\(p.gitAheadCount) ↓\(p.gitBehindCount)",
                        icon: "arrow.triangle.2.circlepath",
                        color: .cyan
                    )
                }
            }

            // Recent Commit
            if !p.lastCommitMessage.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 1)
                    Text(p.lastCommitMessage)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
            }

            // Switch Project Menu
            if service.candidateProjects.count > 1 {
                Menu {
                    ForEach(service.candidateProjects, id: \.self) { path in
                        Button(action: {
                            service.selectProject(at: path)
                        }) {
                            HStack {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                if path == p.path {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.gearshape")
                        Text("Switch Active Project...")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                }
                .menuStyle(.borderlessButton)
            }

            Divider().background(Color.white.opacity(0.12))

            // Quick Developer Actions
            Text("QUICK ACTIONS")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.white.opacity(0.45))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(p.actions) { action in
                    Button(action: {
                        service.executeAction(action)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(width: 14)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(action.title)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                if let sub = action.subtitle {
                                    Text(sub)
                                        .font(.system(size: 8.5))
                                        .foregroundColor(.white.opacity(0.5))
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
    }
}

private struct GitBadgeView: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }
}
