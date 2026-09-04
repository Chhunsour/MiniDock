import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var cityInput: String = ""
    @State private var latInput: String = ""
    @State private var lonInput: String = ""
    
    public init() {}
    
    public var body: some View {
        TabView {
            // General & Appearance
            Form {
                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Dock Scale")
                            Spacer()
                            Text(String(format: "%.0f%%", settings.dockScale * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.dockScale, in: 0.8...1.25, step: 0.05)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Dark Acrylic Opacity")
                            Spacer()
                            Text(String(format: "%.0f%%", settings.backgroundOpacity * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.backgroundOpacity, in: 0.4...0.95, step: 0.05)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Corner Radius")
                            Spacer()
                            Text("\(Int(settings.cornerRadius)) pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.cornerRadius, in: 18...36, step: 1)
                    }
                }
                
                Section("System Dock & Startup") {
                    Toggle("Auto-Hide Apple Dock", isOn: $settings.autoHideAppleDock)
                        .onChange(of: settings.autoHideAppleDock) { _, newValue in
                            DockManager.shared.setAppleDockAutoHide(newValue)
                        }
                    
                    Toggle("Start MiniDock at Login", isOn: $settings.launchAtLogin)
                    
                    Button("Restore Apple Dock Now") {
                        DockManager.shared.restoreAppleDock()
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(18)
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            // Widgets Configuration
            Form {
                Section("Visible Widgets") {
                    Toggle("Clock Widget", isOn: $settings.showClock)
                    Toggle("Weather Widget", isOn: $settings.showWeather)
                    Toggle("App Launcher (2x2)", isOn: $settings.showLauncher)
                    Toggle("System Monitor Ring", isOn: $settings.showSystem)
                    Toggle("Now Playing Media", isOn: $settings.showNowPlaying)
                }
                
                Section("System Metric Focus") {
                    Picker("Ring Metric", selection: $settings.systemMetric) {
                        ForEach(SystemMetricType.allCases) { metric in
                            Label(metric.rawValue, systemImage: metric.icon).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(18)
            .tabItem {
                Label("Widgets", systemImage: "square.grid.2x2")
            }
            
            // Weather Settings
            Form {
                Section("Location & Source") {
                    TextField("City Name", text: $settings.weatherCity)
                    TextField("Latitude", value: $settings.weatherLatitude, format: .number)
                    TextField("Longitude", value: $settings.weatherLongitude, format: .number)
                    
                    Picker("Units", selection: $settings.tempUnit) {
                        Text("Celsius (°C)").tag("°C")
                        Text("Fahrenheit (°F)").tag("°F")
                    }
                    .pickerStyle(.segmented)
                    
                    Button("Quick Set: Phnom Penh, Cambodia") {
                        settings.weatherCity = "Phnom Penh"
                        settings.weatherLatitude = 11.5564
                        settings.weatherLongitude = 104.9282
                        WeatherService.shared.fetchWeather()
                    }
                    
                    Button("Refresh Weather Now") {
                        WeatherService.shared.fetchWeather()
                    }
                }
            }
            .padding(18)
            .tabItem {
                Label("Weather", systemImage: "cloud.sun")
            }
        }
        .frame(width: 440, height: 380)
    }
}
