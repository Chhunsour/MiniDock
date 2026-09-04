import SwiftUI
import AppKit

public struct FocusWidgetView: View {
    @ObservedObject private var focus = FocusService.shared
    @State private var showingPopover = false
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            Button(action: {
                showingPopover.toggle()
            }) {
                HStack(spacing: 10) {
                    // Mini progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 3.5)
                            .frame(width: 28, height: 28)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(max(focus.progress, 0.04)))
                            .stroke(
                                LinearGradient(
                                    colors: focus.isRunning ? [Color.orange, Color.yellow] : [Color.orange.opacity(0.6), Color.yellow.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 28, height: 28)
                            .animation(.easeInOut(duration: 0.3), value: focus.progress)
                        
                        Image(systemName: focus.isRunning ? "bolt.fill" : "timer")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(focus.isRunning ? .orange : .white.opacity(0.7))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(focus.formattedRemainingTime)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.white)
                                .fixedSize()
                            
                            if focus.isRunning {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 5, height: 5)
                                    .shadow(color: .orange, radius: 2)
                            }
                        }
                        
                        Text(focus.taskLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                            .fixedSize()
                    }
                    .frame(minWidth: 70, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover, arrowEdge: .top) {
                FocusDetailPopover(focus: focus)
            }
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
