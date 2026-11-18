import FITReader
import Foundation

struct WeatherHour: Equatable, Sendable {
    let start: Date
    let temperature: Double
    let dewPoint: Double?
}

struct WeatherRequest: Hashable, Sendable {
    let latitude: String
    let longitude: String
    let firstDay: String
    let lastDay: String
    let archive: Bool
}
