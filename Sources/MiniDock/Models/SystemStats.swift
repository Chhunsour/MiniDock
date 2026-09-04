import Foundation
import SwiftUI

public struct SystemStats {
    public var cpuUsage: Double = 0.0
    public var ramUsage: Double = 0.0
    public var ramUsedGB: Double = 0.0
    public var ramTotalGB: Double = 0.0
    public var diskUsage: Double = 0.0
    public var diskUsedGB: Double = 0.0
    public var diskTotalGB: Double = 0.0
    public var netDownloadKBps: Double = 0.0
    public var netUploadKBps: Double = 0.0
    
    public init() {}
    
    public func percentage(for metric: SystemMetricType) -> Double {
        switch metric {
        case .cpu: return cpuUsage
        case .ram: return ramUsage
        case .disk: return diskUsage
        case .combined: return (cpuUsage + ramUsage) / 2.0
        }
    }
    
    public func gradientColors(for metric: SystemMetricType) -> [Color] {
        let value = percentage(for: metric)
        if value > 80 {
            return [Color.red, Color.orange]
        } else if value > 50 {
            return [Color.orange, Color.yellow]
        } else {
            return [Color.green, Color.mint]
        }
    }
    
    public var formattedDownloadSpeed: String {
        if netDownloadKBps > 1024 {
            return String(format: "%.1f MB/s", netDownloadKBps / 1024.0)
        } else {
            return String(format: "%.0f KB/s", netDownloadKBps)
        }
    }
    
    public var formattedUploadSpeed: String {
        if netUploadKBps > 1024 {
            return String(format: "%.1f MB/s", netUploadKBps / 1024.0)
        } else {
            return String(format: "%.0f KB/s", netUploadKBps)
        }
    }
}
