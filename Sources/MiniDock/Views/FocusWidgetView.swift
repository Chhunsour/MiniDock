import SwiftUI
import AppKit

public struct FocusWidgetView: View {
    @ObservedObject private var focus = FocusService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingPopover = false
    @State private var isHovered = false

    public init() {}

    public var body: some View {
        Button(action: {
            showingPopover.toggle()
        }) {
            HStack(spacing: 6) {
                // Focus Dot
                ZStack {
                    Circle()
                        .fill(focus.isRunning ? settings.activeAccentColor : Color.white.opacity(0.28))
                        .frame(width: 6, height: 6)

                    if focus.isRunning {
                        Circle()
                            .stroke(settings.activeAccentColor.opacity(0.40), lineWidth: 1)
                            .frame(width: 12, height: 12)
                    }
                }
                .frame(width: 14, height: 14)

                Text(focus.isRunning ? focus.formattedRemainingTime : "\(focus.currentMode.durationSeconds / 60)m")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isHovered || focus.isRunning ? .white : .white.opacity(0.80))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .center)
            }
            .frame(width: 68, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.075 : (focus.isRunning ? 0.045 : 0)))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(focus.isRunning ? "Focus Active: \(focus.formattedRemainingTime)" : "Start Focus Session")
        .popover(isPresented: $showingPopover, arrowEdge: .top) {
            FocusDetailPopover(focus: focus)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Text("Focus Session (\(focus.formattedRemainingTime))").font(.headline)
            Divider()

            Button("Start 25m Focus") {
                focus.switchMode(.focus25)
                focus.start()
            }

            Button("Start 50m Deep Work") {
                focus.switchMode(.focus50)
                focus.start()
            }

            Button("Start 90m Flow State") {
                focus.switchMode(.focus90)
                focus.start()
            }

            Button("5m Short Break") {
                focus.switchMode(.shortBreak)
                focus.start()
            }

            Button("15m Long Break") {
                focus.switchMode(.longBreak)
                focus.start()
            }

            Divider()

            Button(focus.isRunning ? "Pause Session" : "Resume Session") {
                focus.togglePlayPause()
            }
            .disabled(!focus.isRunning && !focus.isPaused)

            Button("End Session / Reset") {
                focus.reset()
            }

            Divider()

            Button("Focus Settings...") {
                MenuBarController.shared.openSettings(tab: .focus)
            }

            Button("FlowDock Settings...") {
                MenuBarController.shared.openSettings(tab: .general)
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
