import Foundation
import TrainingCore

enum RaceWeatherSource: String, Equatable, Sendable, Codable {
    case forecast, typical
}

struct RaceWeatherReading: Equatable, Sendable, Codable {
    let effect: WeatherEffect
    let source: RaceWeatherSource
    let startHour: Int
    let endHour: Int
    let predictionSeconds: Double

    var adjustedSeconds: Double { WeatherAdjustment.weatherSeconds(predictionSeconds, effect: effect) }
}

struct RaceWeatherKey: Hashable, Sendable {
    let latitude: String
    let longitude: String
    let day: Day
    let startMinutes: Int
    let durationMinutes: Int
}
