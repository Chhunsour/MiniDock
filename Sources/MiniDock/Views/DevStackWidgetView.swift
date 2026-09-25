import SwiftUI
import AppKit

public struct DevStackWidgetView: View {
    @ObservedObject private var devStack = DevStackService.shared
    @State private var showingPopover = false
    @State private var isHovered = false
    @State private var isBeaconPulsing = false
    @State private var scanSpin = false

    public init() {}

    private var hasServices: Bool {
        !devStack.activeServices.isEmpty
    }

    private var headline: String {
        devStack.summaryHeadline
    }

    private var subtext: String {
        devStack.summarySubtext
    }

    public var body: some View {
        let isLiquidGlass = AppSettings.shared.isGlassLike
        WidgetCardView(onHoverChanged: { isHovered = $0 }) {
            Button(action: {
                showingPopover.toggle()
            }) {
                HStack(spacing: 7) {
                    // 1. Status Indicator / Icon (22 x 22 fixed)
                    statusIcon

                    if !isLiquidGlass || hasServices {
                        // Title & subtitle stay compact in the dock; details live in the popover.
                        VStack(alignment: .leading, spacing: 1) {
                            Text(headline)
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text(subtext)
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(width: isLiquidGlass ? 104 : 122, alignment: .leading)

                        // 3. Nested circular chevron/status control (20 x 20 fixed)
                        statusControl
                    }
                }
                .frame(width: (isLiquidGlass && !hasServices) ? 28 : (isLiquidGlass ? 162 : 180), height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(helpTooltip)
            .accessibilityLabel("Local Services: \(headline)")
            .popover(isPresented: $showingPopover, arrowEdge: .top) {
                DevStackDetailPopover(devStack: devStack)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isBeaconPulsing = true
            }
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                scanSpin = true
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            if devStack.isScanning {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 18, height: 18)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .rotationEffect(.degrees(scanSpin ? 360 : 0))
            } else if hasServices {
                Circle()
                    .fill(Color(red: 0.20, green: 0.85, blue: 0.45).opacity(isBeaconPulsing ? 0.32 : 0.12))
                    .frame(width: isBeaconPulsing ? 17 : 14, height: isBeaconPulsing ? 17 : 14)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.45, green: 0.98, blue: 0.60), Color(red: 0.18, green: 0.80, blue: 0.40)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 3
                        )
                    )
                    .frame(width: 5.5, height: 5.5)
                    .shadow(color: Color(red: 0.20, green: 0.85, blue: 0.45).opacity(0.85), radius: 3)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 18, height: 18)

                Image(systemName: "network")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .frame(width: 18, height: 18)
    }

    @ViewBuilder
    private var statusControl: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(isHovered ? 0.12 : 0.04))
                .frame(width: 18, height: 18)

            Image(systemName: showingPopover ? "chevron.up" : "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(hasServices ? 0.70 : 0.35))
        }
        .frame(width: 20, height: 20)
    }

    private var helpTooltip: String {
        if hasServices {
            return "Local Services: \(headline) · \(subtext) (Click for details)"
        } else {
            return "Local Services: No active listeners (Click to scan)"
        }
    }
}

private struct DevStackDetailPopover: View {
    @ObservedObject var devStack: DevStackService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Title, Active Count Badge, Refresh Button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)

                    Text("Local Services")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("\(devStack.activeServices.count) active")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.08)))

                    Button(action: {
                        devStack.scanServices()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.white.opacity(devStack.isScanning ? 0.4 : 0.8))
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .disabled(devStack.isScanning)
                    .help("Refresh Services")
                }
            }

            Divider()
                .background(Color.white.opacity(0.12))

            // Docker status: ONLY shown when Docker is running or containers exist
            if devStack.dockerRunning || devStack.dockerContainersCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 13))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Docker Engine")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        Text(devStack.dockerRunning ? "\(devStack.dockerContainersCount) containers running" : "Daemon not running")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Spacer()

                    Circle()
                        .fill(devStack.dockerRunning ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.8)
                )
            }

            // Services Section
            if devStack.activeServices.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 8)

                    Text("No Local Services Detected")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))

                    Text("Listening web applications, development servers, and local databases will appear here automatically.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.50))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                SleekScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(devStack.activeServices) { service in
                            ServiceRowView(service: service, devStack: devStack)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
    }
}

private struct ServiceRowView: View {
    let service: DevServiceItem
    @ObservedObject var devStack: DevStackService
    @State private var isRowHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Live green dot
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .shadow(color: Color.green.opacity(0.6), radius: 2)

            // Project / Service info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(service.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(service.stack)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(.blue.opacity(0.9))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.16))
                        )
                }

                Text("localhost:\(service.port) · \(service.processName) (PID \(service.pid))")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            // Port badge
            Text(":\(service.port)")
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.70))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )

            // Open in browser button (only when urlString != nil)
            if let url = service.urlString {
                Button(action: {
                    devStack.openURL(url)
                }) {
                    HStack(spacing: 3) {
                        Text("Open")
                            .font(.system(size: 9.5, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.blue.opacity(isRowHovered ? 0.35 : 0.22))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.blue.opacity(0.4), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .help("Open \(url) in browser")
                .accessibilityLabel("Open in browser")
            }

            // Safe Stop / Force Stop action button
            if service.isEligibleForShutdown {
                Button(action: {
                    confirmAndStopService()
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.red.opacity(isRowHovered ? 0.28 : 0.16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.35), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .help("Stop service on port \(service.port) (PID \(service.pid))")
                .accessibilityLabel("Stop \(service.name) service")
            } else {
                Image(systemName: "lock.shield")
                    .font(.system(size: 8.5))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(width: 20, height: 22)
                    .help("Protected system or container process cannot be stopped from FlowDock")
                    .accessibilityLabel("Protected service")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(isRowHovered ? 0.06 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(isRowHovered ? 0.10 : 0.04), lineWidth: 0.8)
        )
        .onHover { isRowHovered = $0 }
    }

    private func confirmAndStopService() {
        let alert = NSAlert()
        alert.messageText = "Stop \(service.name)?"

        let siblingPorts = devStack.activeServices.filter { $0.pid == service.pid }.map { ":\($0.port)" }
        let portsMessage: String
        if siblingPorts.count > 1 {
            portsMessage = "Port: :\(service.port)\nNote: This process also listens on \(siblingPorts.joined(separator: ", ")). Stopping this process will close all associated ports."
        } else {
            portsMessage = "Port: :\(service.port)"
        }

        alert.informativeText = "Process: \(service.processName) (PID \(service.pid))\n\(portsMessage)\n\nStop sends a graceful shutdown request (SIGTERM). Force Stop immediately terminates the process (SIGKILL)."
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Stop")
        let forceBtn = alert.addButton(withTitle: "Force Stop")
        forceBtn.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Task {
                await devStack.stopService(service, type: .graceful)
            }
        } else if response == .alertSecondButtonReturn {
            Task {
                await devStack.stopService(service, type: .force)
            }
        }
    }
}
