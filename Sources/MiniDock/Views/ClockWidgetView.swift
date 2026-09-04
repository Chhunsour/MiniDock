import SwiftUI
import Combine
import AppKit

public struct ClockWidgetView: View {
    @State private var currentTime = Date()
    @State private var timer: AnyCancellable?
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    private var secondsFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "ss"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            Button(action: {
                if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
                    NSWorkspace.shared.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration())
                }
            }) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(timeFormatter.string(from: currentTime))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.white)
                            
                            Text(secondsFormatter.string(from: currentTime))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .fixedSize()
                        
                        Text(dateFormatter.string(from: currentTime))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize()
                    }
                }
                .fixedSize()
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            timer = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { date in
                    currentTime = date
                }
        }
        .onDisappear {
            timer?.cancel()
        }
    }
}
