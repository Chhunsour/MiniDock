import Foundation
import SwiftUI

public struct OpenMeteoResponse: Codable {
    public let latitude: Double
    public let longitude: Double
    public let timezone: String
    public let current: CurrentWeather?
    public let daily: DailyWeather?
    public let hourly: HourlyWeather?
    
    public struct CurrentWeather: Codable {
        public let temperature_2m: Double
        public let relative_humidity_2m: Int?
        public let weather_code: Int
        public let is_day: Int?
    }
    
    public struct DailyWeather: Codable {
        public let temperature_2m_max: [Double]
        public let temperature_2m_min: [Double]
        public let weather_code: [Int]
    }
    
    public struct HourlyWeather: Codable {
        public let time: [String]
        public let temperature_2m: [Double]
        public let weather_code: [Int]
    }
}

public struct HourlyForecastItem: Identifiable {
    public let id = UUID()
    public let hourLabel: String
    public let temperature: Int
    public let icon: String
    public let iconColor: Color
}

public struct WeatherDisplayData {
    public var temperature: Int = 30
    public var conditionText: String = "Partly Cloudy"
    public var iconName: String = "cloud.sun.fill"
    public var iconColor: Color = .yellow
    public var highTemp: Int = 33
    public var lowTemp: Int = 25
    public var humidity: Int = 65
    public var cityName: String = "Phnom Penh"
    public var hourlyForecast: [HourlyForecastItem] = []
    
    public static func conditionInfo(for code: Int, isDay: Bool = true) -> (text: String, icon: String, color: Color) {
        switch code {
        case 0:
            return isDay ? ("Clear", "sun.max.fill", .yellow) : ("Clear", "moon.stars.fill", .indigo)
        case 1:
            return isDay ? ("Mainly Clear", "sun.min.fill", .yellow) : ("Mainly Clear", "moon.fill", .indigo)
        case 2:
            return isDay ? ("Partly Cloudy", "cloud.sun.fill", .orange) : ("Partly Cloudy", "cloud.moon.fill", .indigo)
        case 3:
            return ("Overcast", "cloud.fill", .gray)
        case 45, 48:
            return ("Foggy", "cloud.fog.fill", .gray)
        case 51, 53, 55:
            return ("Drizzle", "cloud.drizzle.fill", .cyan)
        case 61, 63, 65:
            return ("Rain", "cloud.rain.fill", .blue)
        case 71, 73, 75, 77:
            return ("Snow", "snowflake", .white)
        case 80, 81, 82:
            return ("Showers", "cloud.heavyrain.fill", .blue)
        case 95, 96, 99:
            return ("Thunderstorm", "cloud.bolt.rain.fill", .purple)
        default:
            return ("Fair", "cloud.sun.fill", .yellow)
        }
    }
}
