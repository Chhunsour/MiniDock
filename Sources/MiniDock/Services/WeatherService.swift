import Foundation
import Combine
import CoreLocation

@MainActor
public final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = WeatherService()
    
    @Published public var weather = WeatherDisplayData()
    @Published public var isLoading: Bool = false
    @Published public var lastUpdated: Date?
    
    private var timer: AnyCancellable?
    private var locationManager: CLLocationManager?
    
    private override init() {
        super.init()
        fetchWeather()
        
        // Refresh every 15 minutes
        timer = Timer.publish(every: 900, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchWeather()
            }
    }
    
    public func fetchWeather() {
        isLoading = true
        let settings = AppSettings.shared
        let lat = settings.weatherLatitude
        let lon = settings.weatherLongitude
        let cityName = settings.weatherCity
        
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,weather_code,is_day&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1"
        
        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    self.isLoading = false
                    return
                }
                
                let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                self.processWeatherResponse(decoded, cityName: cityName)
                self.lastUpdated = Date()
            } catch {
                print("Weather fetch error: \(error.localizedDescription)")
            }
            self.isLoading = false
        }
    }
    
    private func processWeatherResponse(_ response: OpenMeteoResponse, cityName: String) {
        var display = WeatherDisplayData()
        display.cityName = cityName
        
        if let current = response.current {
            let tempC = current.temperature_2m
            display.temperature = Int(round(tempC))
            display.humidity = current.relative_humidity_2m ?? 65
            let isDay = (current.is_day ?? 1) == 1
            let info = WeatherDisplayData.conditionInfo(for: current.weather_code, isDay: isDay)
            display.conditionText = info.text
            display.iconName = info.icon
            display.iconColor = info.color
        }
        
        if let daily = response.daily,
           let maxTemp = daily.temperature_2m_max.first,
           let minTemp = daily.temperature_2m_min.first {
            display.highTemp = Int(round(maxTemp))
            display.lowTemp = Int(round(minTemp))
        }
        
        // Build 4-hour forecast
        if let hourly = response.hourly {
            let calendar = Calendar.current
            let currentHour = calendar.component(.hour, from: Date())
            var items: [HourlyForecastItem] = []
            
            for index in 0..<min(hourly.time.count, hourly.temperature_2m.count) {
                // Find next 4 upcoming hours
                if index >= currentHour && items.count < 4 {
                    let hour = index % 24
                    let label = hour == currentHour ? "Now" : "\(hour):00"
                    let temp = Int(round(hourly.temperature_2m[index]))
                    let code = index < hourly.weather_code.count ? hourly.weather_code[index] : 0
                    let info = WeatherDisplayData.conditionInfo(for: code, isDay: hour >= 6 && hour < 18)
                    items.append(HourlyForecastItem(hourLabel: label, temperature: temp, icon: info.icon, iconColor: info.color))
                }
            }
            display.hourlyForecast = items
        }
        
        self.weather = display
    }
}
