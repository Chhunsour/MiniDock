import SwiftUI
import AppKit

public struct RepoWidgetView: View {
    @ObservedObject private var repoService = RepoService.shared
    @State private var showingPopover = false
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            Button(action: {
                showingPopover.toggle()
            }) {
                HStack(spacing: 9) {
                    // Git branch icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.18))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repoService.currentRepo.repoName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize()
                        
                        HStack(spacing: 5) {
                            Text(repoService.currentRepo.branch)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("·")
                                .foregroundColor(.white.opacity(0.4))
                            
                            if repoService.currentRepo.isClean {
                                HStack(spacing: 2) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                    Text("clean")
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                            } else {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 4.5, height: 4.5)
                                    Text("+\(repoService.currentRepo.changedFilesCount)")
                                }
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.orange)
                            }
                        }
                        .fixedSize()
                    }
                    .frame(minWidth: 80, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover, arrowEdge: .top) {
                RepoDetailPopover(repoService: repoService)
            }
        }
    }
}

private struct RepoDetailPopover: View {
    @ObservedObject var repoService: RepoService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label("Repository Context", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    repoService.refreshRepoStatus()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Switch Repo Picker
            if repoService.knownRepos.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE PROJECT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Picker("Repo", selection: Binding(
                        get: { repoService.currentRepo.repoPath },
                        set: { repoService.selectRepo(at: $0) }
                    )) {
                        ForEach(repoService.knownRepos, id: \.self) { path in
                            Text(URL(fileURLWithPath: path).lastPathComponent).tag(path)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            // Status Summary
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Branch:")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Text(repoService.currentRepo.branch)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text(repoService.currentRepo.isClean ? "Working tree clean" : "\(repoService.currentRepo.changedFilesCount) uncommitted changes")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(repoService.currentRepo.isClean ? .green : .orange)
                }
                
                if !repoService.currentRepo.lastCommitMessage.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latest Commit:")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        Text(repoService.currentRepo.lastCommitMessage)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Quick Action Shortcuts
            HStack(spacing: 8) {
                Button(action: {
                    repoService.openInEditor("Visual Studio Code")
                }) {
                    Text("VS Code")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    repoService.openInEditor("Cursor")
                }) {
                    Text("Cursor")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    repoService.openInTerminal()
                }) {
                    Text("Terminal")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color.black.opacity(0.92))
    }
}
