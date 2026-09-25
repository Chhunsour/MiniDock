import SwiftUI
import AppKit

public struct SystemWidgetView: View {
    @ObservedObject private var monitor = SystemMonitorService.shared
    @ObservedObject private var devStack = DevStackService.shared
    @State private var showingDiagnostics = false
    @State private var isHovered = false

    public init() {}

    public var body: some View {
        let exceptions = monitor.stats.activeExceptions
        let hasException = !exceptions.isEmpty
        let cpu = monitor.stats.cpuUsage
        let cpuColor: Color = cpu >= 80 ? Color(red: 1.0, green: 0.32, blue: 0.35) : (cpu >= 60 ? Color(red: 1.0, green: 0.65, blue: 0.20) : Color(red: 0.35, green: 0.80, blue: 1.0))

        WidgetCardView(onHoverChanged: { isHovered = $0 }) {
            Button(action: {
                showingDiagnostics.toggle()
            }) {
                if hasException, let first = exceptions.first {
                    // Warning Capsule (Exception-First)
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(first.isCritical ? .red : .orange)

                        Text(first.title)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(first.isCritical ? .red : .orange)
                            .lineLimit(1)
                    }
                    .frame(height: 24)
                    .contentShape(Rectangle())
                } else {
                    // Quiet Resting Indicator with Live Micro Meter
                    HStack(spacing: 4.5) {
                        Image(systemName: "cpu")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(cpuColor.opacity(isHovered ? 1.0 : 0.85))
                            .scaleEffect(isHovered ? 1.12 : 1.0)
                            .shadow(color: cpuColor.opacity(isHovered ? 0.65 : 0), radius: 3)
                            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovered)

                        Text("\(Int(cpu))%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(isHovered ? .white : .white.opacity(0.85))
                            .monospacedDigit()

                        // Micro Activity Bar (14 x 3.5) with fluid spring physics
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [cpuColor, cpuColor.opacity(0.70)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(2, 14 * CGFloat(min(1.0, max(0.06, cpu / 100.0)))))
                        }
                        .frame(width: 14, height: 3.5)
                        .animation(.spring(response: 0.38, dampingFraction: 0.75), value: cpu)
                    }
                    .frame(height: 24)
                    .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .help(hasException ? "System Diagnostics (Issues detected)" : "System Diagnostics (CPU \(Int(cpu))% · RAM \(String(format: "%.1f", monitor.stats.ramUsedGB)) GB)")
            .popover(isPresented: $showingDiagnostics, arrowEdge: .top) {
                SystemDiagnosticsPopover(monitor: monitor, devStack: devStack)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Text("System Diagnostics").font(.headline)
            Divider()

            Button("Open Diagnostics Details") {
                showingDiagnostics.toggle()
            }

            Button("Launch Activity Monitor") {
                if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                    NSWorkspace.shared.open(appUrl)
                }
            }

            Divider()

            Text("CPU: \(String(format: "%.1f%%", monitor.stats.cpuUsage))")
            Text("RAM: \(Int(monitor.stats.ramUsage))% (\(String(format: "%.1f", monitor.stats.ramUsedGB))/\(String(format: "%.0f", monitor.stats.ramTotalGB)) GB)")
            Text("Disk Free: \(String(format: "%.0f GB", monitor.stats.diskFreeGB))")
            if let ext = monitor.stats.externalStorage {
                Text("\(ext.name) Free: \(String(format: "%.0f GB", ext.freeGB))")
            }
            Text("Net: ↓ \(monitor.stats.formattedDownloadSpeed)  ↑ \(monitor.stats.formattedUploadSpeed)")

            Divider()

            Button("System Settings...") {
                MenuBarController.shared.openSettings(tab: .system)
            }

            Button("FlowDock Settings...") {
                MenuBarController.shared.openSettings(tab: .general)
            }
        }
    }
}

private struct SystemDiagnosticsPopover: View {
    @ObservedObject var monitor: SystemMonitorService
    @ObservedObject var devStack: DevStackService
    @State private var isActivityHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.35), Color.purple.opacity(0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.6)
                        )

                    Image(systemName: "gauge.with.dots.needle.bottom.half")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("System Diagnostics")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(monitor.stats.cpuUsage > 80 ? Color.orange : Color.green)
                            .frame(width: 5, height: 5)
                            .shadow(color: (monitor.stats.cpuUsage > 80 ? Color.orange : Color.green).opacity(0.6), radius: 2)

                        Text(monitor.stats.cpuUsage > 80 ? "Elevated CPU Load" : "All Systems Operational")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                Spacer()

                Button {
                    if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                        NSWorkspace.shared.open(appUrl)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Activity Monitor")
                            .font(.system(size: 10, weight: .medium))
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.white.opacity(isActivityHovered ? 1.0 : 0.75))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(isActivityHovered ? 0.12 : 0.05))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(isActivityHovered ? 0.22 : 0.08), lineWidth: 0.6)
                            )
                    )
                }
                .buttonStyle(.plain)
                .onHover { isActivityHovered = $0 }
            }

            // 2x2 Bento Metric Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                // CPU Card
                MetricCardView(
                    title: "CPU Load",
                    icon: "cpu",
                    primaryValue: String(format: "%.1f%%", monitor.stats.cpuUsage),
                    secondaryValue: monitor.stats.cpuUsage > 80 ? "Heavy" : "Normal",
                    progress: monitor.stats.cpuUsage / 100.0,
                    gradient: monitor.stats.cpuUsage > 80 ? [Color.orange, Color.red] : [Color.blue, Color.cyan]
                )

                // Memory Card
                MetricCardView(
                    title: "Memory (RAM)",
                    icon: "memorychip",
                    primaryValue: String(format: "%.1f GB", monitor.stats.ramUsedGB),
                    secondaryValue: "of \(String(format: "%.0f", monitor.stats.ramTotalGB)) GB",
                    progress: monitor.stats.ramUsage / 100.0,
                    gradient: monitor.stats.ramUsage > 85 ? [Color.red, Color.orange] : [Color.purple, Color.indigo]
                )

                // Storage Card
                MetricCardView(
                    title: "Macintosh HD",
                    icon: "internaldrive",
                    primaryValue: "\(String(format: "%.0f", monitor.stats.diskFreeGB)) GB",
                    secondaryValue: "Free Space",
                    progress: monitor.stats.diskUsage / 100.0,
                    gradient: monitor.stats.diskFreeGB < 12 ? [Color.red, Color.orange] : [Color.teal, Color.mint]
                )

                // Network Card
                NetworkCardView(
                    downloadSpeed: monitor.stats.formattedDownloadSpeed,
                    uploadSpeed: monitor.stats.formattedUploadSpeed
                )
            }

            // Top Applications (Activity Monitor style)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("TOP APPLICATIONS")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Text("By CPU Load")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.40))
                }

                if monitor.topApplications.isEmpty {
                    Text("No user applications detected")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.vertical, 8)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(monitor.topApplications.prefix(10)) { app in
                                TopAppRowView(app: app, monitor: monitor)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: 148)
                }
            }

            // Docker & Dev Stack Status
            if devStack.dockerRunning || !devStack.activeServices.isEmpty {
                Divider().background(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 6) {
                    Text("DEV SERVICES")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))

                    if devStack.dockerRunning {
                        HStack(spacing: 6) {
                            Image(systemName: "cube.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text("Docker Engine")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(devStack.dockerContainersCount) containers")
                                .font(.system(size: 9.5, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                        )
                    }

                    ForEach(devStack.activeServices.prefix(3)) { s in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                                .shadow(color: Color.green.opacity(0.6), radius: 2)

                            Text(s.name)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.white)

                            Spacer()

                            Text(verbatim: ":\(s.port)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.02))
                        )
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 375)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.85))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                .allowsHitTesting(false)
        )
    }
}

private struct MetricCardView: View {
    let title: String
    let icon: String
    let primaryValue: String
    let secondaryValue: String
    let progress: Double
    let gradient: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.50))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.50))
                Spacer()
            }

            HStack(alignment: .lastTextBaseline) {
                Text(primaryValue)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(secondaryValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.40))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 3.5)

                    Capsule()
                        .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.width * CGFloat(min(progress, 1.0)), 4), height: 3.5)
                }
            }
            .frame(height: 3.5)
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.6)
                )
        )
    }
}

private struct NetworkCardView: View {
    let downloadSpeed: String
    let uploadSpeed: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "network")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.50))
                Text("Network Activity")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.50))
                Spacer()
            }

            VStack(spacing: 3) {
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.green)
                        Text("Down")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                    Text(downloadSpeed)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }

                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("Up")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                    Text(uploadSpeed)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.6)
                )
        )
    }
}

private struct TopAppRowView: View {
    let app: RunningApplicationUsage
    @ObservedObject var monitor: SystemMonitorService
    @State private var isRowHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("PID \(String(app.pid))")
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // CPU % Badge
            Text(String(format: "%.1f%%", app.cpuUsage))
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(app.cpuUsage > 20.0 ? .orange : .white.opacity(0.9))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(app.cpuUsage > 20.0 ? Color.orange.opacity(0.18) : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(app.cpuUsage > 20.0 ? Color.orange.opacity(0.30) : Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                )

            // RAM Badge
            Text(String(format: "%.1f%% M", app.memoryUsage))
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )

            // Quit / Force Quit action
            Button(action: {
                confirmQuitApp()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12.5))
                    .foregroundColor(isRowHovered ? Color.red.opacity(0.85) : Color.white.opacity(0.25))
            }
            .buttonStyle(.plain)
            .help("Quit or Force Quit \(app.name)")
            .accessibilityLabel("Quit \(app.name)")
            .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(isRowHovered ? 0.08 : 0.02))
        )
        .onHover { isRowHovered = $0 }
    }

    private func confirmQuitApp() {
        let alert = NSAlert()
        alert.messageText = "Quit \(app.name)?"
        alert.informativeText = "PID: \(String(app.pid))\nCPU: \(String(format: "%.1f%%", app.cpuUsage)) · RAM: \(String(format: "%.1f%%", app.memoryUsage))\n\nQuit requests a graceful exit. Force Quit terminates the application immediately."
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Quit")
        let forceBtn = alert.addButton(withTitle: "Force Quit")
        forceBtn.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            monitor.quitApplication(app, force: false)
        } else if response == .alertSecondButtonReturn {
            monitor.quitApplication(app, force: true)
        }
    }
}
