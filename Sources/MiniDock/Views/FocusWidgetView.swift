import SwiftUI
import AppKit

public struct FocusWidgetView: View {
    @ObservedObject private var focus = FocusService.shared
    @State private var showingPopover = false
    @State private var isHovered = false
    
    public init() {}
    
    public var body: some View {
        Button(action: {
            showingPopover.toggle()
        }) {
            HStack(spacing: 6) {
                // Focus Dot / Icon
                ZStack {
                    Circle()
                        .fill(focus.isRunning ? Color.orange : Color.white.opacity(0.18))
                        .frame(width: 8, height: 8)
                        .shadow(color: focus.isRunning ? Color.orange.opacity(0.8) : Color.clear, radius: 4)
                    
                    if focus.isRunning {
                        Circle()
                            .stroke(Color.orange.opacity(0.4), lineWidth: 2)
                            .frame(width: 14, height: 14)
                    }
                }
                .frame(width: 16, height: 16)
                
                if isHovered || focus.isRunning {
                    Text(focus.isRunning ? focus.formattedRemainingTime : "\(focus.currentMode.durationSeconds / 60)m")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .transition(.opacity)
                } else {
                    Text("\(focus.currentMode.durationSeconds / 60)m")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.09 : (focus.isRunning ? 0.07 : 0.03)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(focus.isRunning ? Color.orange.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(focus.isRunning ? "Focus Active: \(focus.formattedRemainingTime)" : "Start Focus Session")
        .popover(isPresented: $showingPopover, arrowEdge: .top) {
            FocusDetailPopover(focus: focus)
        }
    }
}

private struct FocusDetailPopover: View {
    @ObservedObject var focus: FocusService
    @State private var customTask: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Focus & Deep Work", systemImage: "brain.head.profile")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if focus.completedSessions > 0 {
                    Text("🔥 \(focus.completedSessions) completed")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Large Timer Display
            VStack(spacing: 4) {
                Text(focus.formattedRemainingTime)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                
                Text(focus.currentMode.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.vertical, 4)
            
            // Primary Play / Pause / Reset controls
            HStack(spacing: 14) {
                Button(action: {
                    focus.togglePlayPause()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: focus.isRunning ? "pause.fill" : "play.fill")
                        Text(focus.isRunning ? "Pause" : (focus.isPaused ? "Resume" : "Start Focus"))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    focus.reset()
                }) {
                    Text("Reset")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Mode buttons
            VStack(alignment: .leading, spacing: 6) {
                Text("Select Session")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                
                HStack(spacing: 6) {
                    ForEach(FocusMode.allCases) { mode in
                        Button(action: {
                            focus.switchMode(mode)
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: focus.currentMode == mode ? .bold : .medium))
                                .foregroundColor(focus.currentMode == mode ? .white : .white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(focus.currentMode == mode ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 290)
        .background(Color.black.opacity(0.9))
    }
}
