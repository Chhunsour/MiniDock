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
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeFormatter.string(from: currentTime))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .fixedSize()
                    
                    Text(dateFormatter.string(from: currentTime))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .fixedSize()
                }
            }
            .buttonStyle(.plain)
            .help("Open Calendar")
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
