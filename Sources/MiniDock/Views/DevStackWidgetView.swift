import SwiftUI
import AppKit

public struct DevStackWidgetView: View {
    @ObservedObject private var devStack = DevStackService.shared
    @State private var showingPopover = false
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            Button(action: {
                showingPopover.toggle()
            }) {
                HStack(spacing: 9) {
                    // Server/Stack Icon with live activity pulse
                    ZStack {
                        Circle()
                            .fill(devStack.activeServices.isEmpty ? Color.white.opacity(0.08) : Color.green.opacity(0.18))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "server.rack")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(devStack.activeServices.isEmpty ? .white.opacity(0.6) : .green)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(devStack.activeServices.isEmpty ? Color.gray : Color.green)
                                .frame(width: 5.5, height: 5.5)
                                .shadow(color: devStack.activeServices.isEmpty ? .clear : .green, radius: 2)
                            
                            Text(devStack.summaryHeadline)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .fixedSize()
                        }
                        
                        Text(devStack.summarySubtext)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .frame(minWidth: 85, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover, arrowEdge: .top) {
                DevStackDetailPopover(devStack: devStack)
            }
        }
    }
}

private struct DevStackDetailPopover: View {
    @ObservedObject var devStack: DevStackService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label("Dev Stack & Ports", systemImage: "network")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    devStack.scanServices()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Docker Status Section
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(devStack.dockerRunning ? .blue : .gray)
                    .font(.system(size: 14))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Docker Engine")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    Text(devStack.dockerRunning ? "\(devStack.dockerContainersCount) containers running" : "Daemon not running")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                Circle()
                    .fill(devStack.dockerRunning ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 7, height: 7)
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            // Active Listening Ports List
            VStack(alignment: .leading, spacing: 6) {
                Text("LISTENING PORTS (\(devStack.activeServices.count))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                
                if devStack.activeServices.isEmpty {
                    Text("No local web or database ports detected.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 6)
                } else {
                    ForEach(devStack.activeServices) { service in
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(service.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("PID \(service.pid) · \(service.processName)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            if let url = service.urlString {
                                Button("Open") {
                                    devStack.openURL(url)
                                }
                                .font(.system(size: 10, weight: .medium))
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(Color.black.opacity(0.92))
    }
}
