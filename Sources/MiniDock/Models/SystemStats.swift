import Foundation
import SwiftUI

public struct SystemException: Identifiable, Equatable {
    public let id: String
    public let icon: String
    public let title: String
    public let detail: String
    public let isCritical: Bool

    public init(id: String, icon: String, title: String, detail: String, isCritical: Bool = false) {
        self.id = id
        self.icon = icon
        self.title = title
        self.detail = detail
        self.isCritical = isCritical
    }
}

public struct VolumeStorageStats: Equatable, Sendable {
    public var name: String
    public var freeGB: Double
    public var percentage: Double

    public init(name: String, freeGB: Double, percentage: Double) {
        self.name = name
        self.freeGB = freeGB
        self.percentage = percentage
    }
}

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
    public var externalStorage: VolumeStorageStats? = nil

    public init() {}

    public var diskFreeGB: Double {
        max(diskTotalGB - diskUsedGB, 0.0)
    }

    public var activeExceptions: [SystemException] {
        var list: [SystemException] = []

        if ramUsage >= 88.0 {
            list.append(SystemException(
                id: "ram",
                icon: "memorychip",
                title: "RAM \(Int(ramUsage))%",
                detail: "\(String(format: "%.1f", ramUsedGB)) GB used",
                isCritical: ramUsage >= 94.0
            ))
        }

        if diskFreeGB < 12.0 && diskTotalGB > 0 {
            list.append(SystemException(
                id: "disk",
                icon: "internaldrive",
                title: "Disk Low",
                detail: "\(Int(diskFreeGB)) GB left",
                isCritical: diskFreeGB < 6.0
            ))
        }

        if cpuUsage >= 85.0 {
            list.append(SystemException(
                id: "cpu",
                icon: "cpu",
                title: "CPU \(Int(cpuUsage))%",
                detail: "High load",
                isCritical: cpuUsage >= 95.0
            ))
        }

        return list
    }

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
