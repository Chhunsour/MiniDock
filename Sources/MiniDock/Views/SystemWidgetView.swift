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
        
        Button(action: {
            showingDiagnostics.toggle()
        }) {
            if hasException, let first = exceptions.first {
                // Warning Capsule (Exception-First)
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(first.isCritical ? .red : .orange)
                    
                    Text(first.title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(first.isCritical ? .red : .orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill((first.isCritical ? Color.red : Color.orange).opacity(0.16))
                        .overlay(
                            Capsule()
                                .stroke((first.isCritical ? Color.red : Color.orange).opacity(0.4), lineWidth: 1)
                        )
                )
            } else {
                // Quiet Resting Indicator
                HStack(spacing: 4) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 11))
                        .foregroundColor(isHovered ? .white : .white.opacity(0.45))
                    
                    if isHovered {
                        Text("\(Int(monitor.stats.ramUsage))%")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(height: 24)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(isHovered ? 0.08 : 0.0))
                )
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("System Diagnostics · Activity Monitor")
        .popover(isPresented: $showingDiagnostics, arrowEdge: .top) {
            SystemDiagnosticsPopover(monitor: monitor, devStack: devStack)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label("System Diagnostics", systemImage: "gauge.with.needle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Activity Monitor") {
                    if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                        NSWorkspace.shared.open(appUrl)
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .buttonStyle(.borderless)
            }
            
            Divider().background(Color.white.opacity(0.12))
            
            // Metrics Grid
            VStack(spacing: 10) {
                // CPU
                MetricRowView(
                    icon: "cpu",
                    title: "CPU Load",
                    value: String(format: "%.1f%%", monitor.stats.cpuUsage),
                    progress: monitor.stats.cpuUsage / 100.0,
                    barColor: monitor.stats.cpuUsage > 80 ? .orange : .blue
                )
                
                // RAM
                MetricRowView(
                    icon: "memorychip",
                    title: "Memory (RAM)",
                    value: "\(String(format: "%.1f", monitor.stats.ramUsedGB)) / \(String(format: "%.0f", monitor.stats.ramTotalGB)) GB",
                    progress: monitor.stats.ramUsage / 100.0,
                    barColor: monitor.stats.ramUsage > 85 ? .orange : .purple
                )
                
                // Disk
                MetricRowView(
                    icon: "internaldrive",
                    title: "Macintosh HD",
                    value: "\(String(format: "%.0f", monitor.stats.diskFreeGB)) GB free",
                    progress: monitor.stats.diskUsage / 100.0,
                    barColor: monitor.stats.diskFreeGB < 12 ? .red : .mint
                )
                
                // Network
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text(monitor.stats.formattedDownloadSpeed)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.cyan)
                        Text(monitor.stats.formattedUploadSpeed)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 2)
            }
            
            // Docker & Dev Stack Status
            if devStack.dockerRunning || !devStack.activeServices.isEmpty {
                Divider().background(Color.white.opacity(0.12))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("DEV SERVICES")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                    
                    if devStack.dockerRunning {
                        HStack {
                            Image(systemName: "cube.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text("Docker Engine")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(devStack.dockerContainersCount) containers")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    ForEach(devStack.activeServices.prefix(3)) { s in
                        HStack {
                            Circle().fill(Color.green).frame(width: 4, height: 4)
                            Text(s.name)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text(":\(s.port)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
    }
}

private struct MetricRowView: View {
    let icon: String
    let title: String
    let value: String
    let progress: Double
    let barColor: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(value)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(geo.size.width * CGFloat(min(progress, 1.0)), 3), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}
