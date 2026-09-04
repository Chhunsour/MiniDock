import SwiftUI
import AppKit

public struct SystemWidgetView: View {
    @ObservedObject private var monitor = SystemMonitorService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingPopover = false
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            Button(action: {
                showingPopover.toggle()
            }) {
                HStack(spacing: 10) {
                    // Concentric Dual Activity Ring (CPU outer, RAM inner)
                    ZStack {
                        // Background tracks
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 2.5)
                            .frame(width: 23, height: 23)
                        
                        // CPU ring (outer)
                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(max(monitor.stats.cpuUsage / 100.0, 0.02), 1.0)))
                            .stroke(
                                LinearGradient(
                                    colors: monitor.stats.cpuUsage > 75 ? [Color.orange, Color.red] : [Color.green, Color.mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 32, height: 32)
                        
                        // RAM ring (inner)
                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(max(monitor.stats.ramUsage / 100.0, 0.02), 1.0)))
                            .stroke(
                                LinearGradient(
                                    colors: monitor.stats.ramUsage > 80 ? [Color.orange, Color.red] : [Color.cyan, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 23, height: 23)
                    }
                    
                    // Glanceable summary
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            HStack(spacing: 3) {
                                Text("CPU")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.green)
                                Text("\(Int(round(monitor.stats.cpuUsage)))%")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.white)
                            }
                            
                            Text("·")
                                .foregroundColor(.white.opacity(0.4))
                            
                            HStack(spacing: 3) {
                                Text("RAM")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.cyan)
                                Text("\(Int(round(monitor.stats.ramUsage)))%")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.white)
                            }
                        }
                        .fixedSize()
                        
                        // Network speed summary
                        HStack(spacing: 6) {
                            Text("↓ \(monitor.stats.formattedDownloadSpeed)")
                            Text("↑ \(monitor.stats.formattedUploadSpeed)")
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize()
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover, arrowEdge: .top) {
                SystemDetailPopover(stats: monitor.stats)
            }
        }
    }
}

private struct SystemDetailPopover: View {
    let stats: SystemStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("System Metrics", systemImage: "speedometer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Activity Monitor") {
                    if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                        NSWorkspace.shared.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration())
                    }
                }
                .font(.system(size: 11))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // CPU Load
            MetricRow(
                icon: "cpu",
                title: "CPU Load",
                valueText: String(format: "%.1f%%", stats.cpuUsage),
                percentage: stats.cpuUsage,
                color: .green
            )
            
            // Memory Load
            MetricRow(
                icon: "memorychip",
                title: "Memory",
                valueText: String(format: "%.1f / %.1f GB (%.0f%%)", stats.ramUsedGB, stats.ramTotalGB, stats.ramUsage),
                percentage: stats.ramUsage,
                color: .cyan
            )
            
            // Disk Space
            MetricRow(
                icon: "internaldrive",
                title: "SSD Storage",
                valueText: String(format: "%.1f / %.1f GB", stats.diskUsedGB, stats.diskTotalGB),
                percentage: stats.diskUsage,
                color: .purple
            )
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Network Throughput
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text("Network Throughput")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                HStack(spacing: 8) {
                    Text("↓ \(stats.formattedDownloadSpeed)")
                    Text("↑ \(stats.formattedUploadSpeed)")
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(Color.black.opacity(0.92))
    }
}

private struct MetricRow: View {
    let icon: String
    let title: String
    let valueText: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(valueText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: max(geo.size.width * CGFloat(min(max(percentage / 100.0, 0.0), 1.0)), 4), height: 5)
                }
            }
            .frame(height: 5)
        }
    }
}
