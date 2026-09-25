import SwiftUI
import AppKit

public struct FocusWidgetView: View {
    @ObservedObject private var focus = FocusService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingPopover = false
    @State private var isHovered = false
    @State private var isPulsing = false

    public init() {}

    public var body: some View {
        WidgetCardView(onHoverChanged: { isHovered = $0 }) {
            Button(action: {
                showingPopover.toggle()
            }) {
                HStack(spacing: 5) {
                    // Status Diode / Chronometer Dial
                    ZStack {
                        if focus.isRunning {
                            Circle()
                                .fill(settings.activeAccentColor.opacity(isPulsing ? 0.35 : 0.14))
                                .frame(width: isPulsing ? 15 : 12, height: isPulsing ? 15 : 12)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.white.opacity(0.95), settings.activeAccentColor],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 3
                                    )
                                )
                                .frame(width: 5.5, height: 5.5)
                                .shadow(color: settings.activeAccentColor.opacity(0.85), radius: 3)
                        } else {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(isHovered ? 0.48 : 0.22), lineWidth: 0.9)
                                    .frame(width: 8, height: 8)
                                Circle()
                                    .fill(Color.white.opacity(isHovered ? 0.90 : 0.45))
                                    .frame(width: 3.2, height: 3.2)
                            }
                            .rotationEffect(.degrees(isHovered ? 30 : 0))
                            .animation(.spring(response: 0.28, dampingFraction: 0.70), value: isHovered)
                        }
                    }
                    .frame(width: 14, height: 14)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }

                    Text(focus.isRunning ? focus.formattedRemainingTime : "\(focus.currentMode.durationSeconds / 60)m")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(focus.isRunning ? settings.activeAccentColor : (isHovered ? .white : .white.opacity(0.85)))
                        .monospacedDigit()
                }
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(focus.isRunning ? "Focus Active: \(focus.formattedRemainingTime)" : "Start Focus Session")
            .popover(isPresented: $showingPopover, arrowEdge: .top) {
                FocusDetailPopover(focus: focus)
            }
        }
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
    @ObservedObject var settings = AppSettings.shared
    @State private var hoveredMode: FocusMode? = nil
    @State private var isPrimaryHovered = false
    @State private var isResetHovered = false
    @State private var isPlus5Hovered = false
    @State private var isSkipHovered = false
    @State private var isSettingsHovered = false

    private var activeColor: Color {
        switch focus.currentMode {
        case .focus25:
            return Color(red: 1.0, green: 0.58, blue: 0.12) // Warm Amber
        case .focus50:
            return Color(red: 1.0, green: 0.40, blue: 0.20) // Fiery Orange
        case .focus90:
            return Color(red: 0.40, green: 0.60, blue: 1.0) // Deep Flow Indigo
        case .shortBreak:
            return Color(red: 0.22, green: 0.85, blue: 0.60) // Mint Emerald
        case .longBreak:
            return Color(red: 0.28, green: 0.80, blue: 0.82) // Calm Cyan
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(activeColor.opacity(0.18))
                        .frame(width: 24, height: 24)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(activeColor)
                }

                Text("Focus & Deep Work")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if focus.completedSessions > 0 {
                    HStack(spacing: 3) {
                        Text("🔥")
                            .font(.system(size: 10))
                        Text("\(focus.completedSessions) done")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.65, blue: 0.25))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 0.8)
                    )
                }

                Button(action: {
                    MenuBarController.shared.openSettings(tab: .focus)
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSettingsHovered ? .white : .white.opacity(0.55))
                        .frame(width: 22, height: 22)
                        .background(isSettingsHovered ? Color.white.opacity(0.12) : Color.clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { isSettingsHovered = $0 }
                .help("Focus Preferences")
            }

            // MARK: - Circular Progress Ring & Timer Dial
            ZStack {
                // Ambient backdrop glow
                Circle()
                    .fill(activeColor.opacity(focus.isRunning ? 0.14 : 0.04))
                    .frame(width: 140, height: 140)
                    .blur(radius: 18)

                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 132, height: 132)

                // Animated Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(max(0.003, focus.progress)))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                activeColor.opacity(0.80),
                                activeColor,
                                activeColor.opacity(0.95)
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 132, height: 132)
                    .shadow(color: activeColor.opacity(focus.isRunning ? 0.45 : 0.20), radius: 6)
                    .animation(.easeInOut(duration: 0.3), value: focus.progress)

                // Center Typographic Core
                VStack(spacing: 3) {
                    // Session badge pill
                    HStack(spacing: 3.5) {
                        Image(systemName: focus.currentMode.iconName)
                            .font(.system(size: 8, weight: .bold))
                        Text(focus.currentMode.defaultLabel.uppercased())
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .tracking(0.6)
                    }
                    .foregroundStyle(activeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(activeColor.opacity(0.16))
                    .clipShape(Capsule())

                    // Monospaced Bold Digits
                    Text(focus.formattedRemainingTime)
                        .font(.system(size: 33, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    // Contextual status text
                    Text(focus.isRunning ? "\(Int(focus.progress * 100))% complete" : (focus.isPaused ? "Paused" : "\(focus.currentMode.durationSeconds / 60)m total"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.vertical, 4)

            // MARK: - Primary Action & Quick Controls
            HStack(spacing: 8) {
                // Primary Action Button (Start / Pause / Resume)
                Button(action: {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                        focus.togglePlayPause()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: focus.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11.5, weight: .bold))
                        Text(focus.isRunning ? "Pause" : (focus.isPaused ? "Resume" : "Start \(focus.currentMode.defaultLabel)"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(focus.isRunning ? .white : Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background {
                        if focus.isRunning {
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.10)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        } else {
                            LinearGradient(
                                colors: [activeColor, activeColor.opacity(0.88)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                focus.isRunning ? activeColor.opacity(0.4) : Color.white.opacity(0.35),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: activeColor.opacity(focus.isRunning ? 0.15 : 0.35), radius: isPrimaryHovered ? 8 : 4, y: 2)
                    .scaleEffect(isPrimaryHovered ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { isPrimaryHovered = $0 }

                // Quick +5m Extension Chip
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        focus.extendTime(by: 5)
                    }
                }) {
                    Text("+5m")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isPlus5Hovered ? .white : .white.opacity(0.85))
                        .frame(width: 42, height: 34)
                        .background(isPlus5Hovered ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isPlus5Hovered = $0 }
                .help("Add 5 Minutes to Session")

                // Reset Button
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        focus.reset()
                    }
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(isResetHovered ? .white : .white.opacity(0.75))
                        .frame(width: 34, height: 34)
                        .background(isResetHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isResetHovered = $0 }
                .help("Reset Session")

                // Skip / Next Button (visible when running or paused)
                if focus.isRunning || focus.isPaused {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            focus.skipSession()
                        }
                    }) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(isSkipHovered ? .white : .white.opacity(0.75))
                            .frame(width: 32, height: 34)
                            .background(isSkipHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isSkipHovered = $0 }
                    .help("Skip / Finish Session")
                }
            }

            // MARK: - Session Presets
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FOCUS INTERVALS")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(0.5)
                    Spacer()
                }

                // Focus Modes Row (3 pills)
                HStack(spacing: 6) {
                    sessionButton(mode: .focus25, label: "25m Sprint", icon: "bolt.fill")
                    sessionButton(mode: .focus50, label: "50m Deep", icon: "target")
                    sessionButton(mode: .focus90, label: "90m Flow", icon: "waveform.path.ecg")
                }

                HStack {
                    Text("RECHARGE INTERVALS")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(0.5)
                    Spacer()
                }

                // Rest Modes Row (2 pills)
                HStack(spacing: 6) {
                    sessionButton(mode: .shortBreak, label: "5m Short Break", icon: "cup.and.saucer.fill")
                    sessionButton(mode: .longBreak, label: "15m Long Rest", icon: "leaf.fill")
                }
            }
        }
        .padding(18)
        .frame(width: 320)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.96), location: 0.0),
                                .init(color: Color(red: 0.03, green: 0.03, blue: 0.05).opacity(0.98), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Top Specular Highlight
                VStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 1)
                    Spacer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }

    @ViewBuilder
    private func sessionButton(mode: FocusMode, label: String, icon: String) -> some View {
        let isSelected = focus.currentMode == mode
        let isHovered = hoveredMode == mode

        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                focus.switchMode(mode)
            }
        }) {
            HStack(spacing: 4.5) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? activeColor : (isHovered ? .white : .white.opacity(0.65)))

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : (isHovered ? .white : .white.opacity(0.75)))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 4)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(activeColor.opacity(0.18))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.white.opacity(0.09) : Color.white.opacity(0.04))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected ? activeColor.opacity(0.55) : (isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.07)),
                        lineWidth: isSelected ? 1.0 : 0.7
                    )
            }
            .shadow(color: isSelected ? activeColor.opacity(0.20) : Color.clear, radius: 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredMode = hovering ? mode : nil
        }
    }
}
