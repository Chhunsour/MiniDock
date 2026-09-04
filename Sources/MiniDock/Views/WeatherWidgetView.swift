import SwiftUI
import AppKit

public struct WeatherWidgetView: View {
    @ObservedObject private var weatherService = WeatherService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var isRefreshing = false
    
    public init() {}
    
    public var body: some View {
        WidgetCardView {
            Button(action: {
                triggerRefresh()
            }) {
                HStack(spacing: 14) {
                    // Weather icon & Current Temp
                    HStack(spacing: 8) {
                        Image(systemName: weatherService.weather.iconName)
                            .renderingMode(.original)
                            .font(.system(size: 26))
                            .symbolRenderingMode(.multicolor)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(weatherService.weather.temperature)\(settings.tempUnit)")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .fixedSize()
                            
                            Text(weatherService.weather.cityName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                                .fixedSize()
                        }
                    }
                    
                    // Condition and High/Low
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weatherService.weather.conditionText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                            .fixedSize()
                        
                        HStack(spacing: 6) {
                            Text("H: \(weatherService.weather.highTemp)°")
                                .foregroundColor(.white.opacity(0.55))
                            Text("L: \(weatherService.weather.lowTemp)°")
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .fixedSize()
                    }
                    
                    // Micro hourly forecast pills (3 upcoming hours)
                    if !weatherService.weather.hourlyForecast.isEmpty {
                        Divider()
                            .frame(height: 28)
                            .background(Color.white.opacity(0.15))
                        
                        HStack(spacing: 8) {
                            ForEach(weatherService.weather.hourlyForecast.prefix(3)) { item in
                                VStack(spacing: 2) {
                                    Text(item.hourLabel)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                        .fixedSize()
                                    
                                    Image(systemName: item.icon)
                                        .font(.system(size: 11))
                                        .foregroundColor(item.iconColor)
                                    
                                    Text("\(item.temperature)°")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.85))
                                        .fixedSize()
                                }
                                .frame(minWidth: 26)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Refresh Weather") {
                    triggerRefresh()
                }
                Button("Open Apple Weather") {
                    if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.weather") {
                        NSWorkspace.shared.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration())
                    }
                }
            }
        }
    }
    
    private func triggerRefresh() {
        isRefreshing = true
        weatherService.fetchWeather()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isRefreshing = false
        }
    }
}
