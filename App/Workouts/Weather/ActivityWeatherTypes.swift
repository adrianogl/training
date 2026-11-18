import FITReader
import Foundation

struct WeatherHour: Equatable, Sendable {
    let start: Date
    let temperature: Double
    let dewPoint: Double?
    var windSpeed: Double?
    var windFrom: Double?
    var radiation: Double?
}

struct ActivityWeatherResponse: Decodable {
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double?]
        let dew_point_2m: [Double?]
        let wind_speed_10m: [Double?]?
        let wind_direction_10m: [Double?]?
        let shortwave_radiation: [Double?]?
    }

    let hourly: Hourly
}

struct WeatherRequest: Hashable, Sendable {
    let latitude: String
    let longitude: String
    let firstDay: String
    let lastDay: String
    let archive: Bool
}
