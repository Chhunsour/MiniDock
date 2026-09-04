import SwiftUI
import AppKit

public struct SystemWidgetView: View {
    @ObservedObject private var monitor = SystemMonitorService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingDetails = false
    
    private var currentMetricValue: Double {
        monitor.stats.percentage(for: settings.systemMetric)
    }
    
    private var gradientColors: [Color] {
        monitor.stats.gradientColors(for: settings.systemMetric)
    }
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            Button(action: {
                showingDetails.toggle()
            }) {
                HStack(spacing: 10) {
                    // Circular Ring Widget
                    ZStack {
                        // Background track
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 4.5)
                            .frame(width: 44, height: 44)
                        
                        // Progress Arc
                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(max(currentMetricValue / 100.0, 0.01), 1.0)))
                            .stroke(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: 44)
                            .animation(.spring(response: 0.6, dampingFraction: 0.72), value: currentMetricValue)
                        
                        // Center icon and value
                        VStack(spacing: 1) {
                            Image(systemName: settings.systemMetric.icon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("\(Int(round(currentMetricValue)))%")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Metric label & secondary stat with fixedSize
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.systemMetric.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .fixedSize()
                        
                        Text(metricSubtext)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .fixedSize()
                    }
                    .frame(minWidth: 44, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingDetails, arrowEdge: .top) {
                SystemDetailPopover(stats: monitor.stats, settings: settings)
            }
        }
    }
    
    private var metricSubtext: String {
        switch settings.systemMetric {
        case .cpu:
            return "Active"
        case .ram:
            return String(format: "%.1f GB", monitor.stats.ramUsedGB)
        case .disk:
            return String(format: "%.0f%% full", monitor.stats.diskUsage)
        case .combined:
            return "Health"
        }
    }
}

private struct SystemDetailPopover: View {
    let stats: SystemStats
    let settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("System Monitor")
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
            
            // CPU Stat
            MetricRow(
                icon: "cpu",
                title: "CPU Load",
                valueText: String(format: "%.1f%%", stats.cpuUsage),
                percentage: stats.cpuUsage,
                color: .green
            )
            
            // RAM Stat
            MetricRow(
                icon: "memorychip",
                title: "Memory",
                valueText: String(format: "%.1f / %.1f GB", stats.ramUsedGB, stats.ramTotalGB),
                percentage: stats.ramUsage,
                color: .cyan
            )
            
            // Disk Stat
            MetricRow(
                icon: "internaldrive",
                title: "Disk Space",
                valueText: String(format: "%.1f / %.1f GB", stats.diskUsedGB, stats.diskTotalGB),
                percentage: stats.diskUsage,
                color: .purple
            )
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Network Speed Stat
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.orange)
                    .font(.system(size: 11))
                Text("Network")
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
        .padding(14)
        .frame(width: 270)
        .background(Color.black.opacity(0.88))
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
