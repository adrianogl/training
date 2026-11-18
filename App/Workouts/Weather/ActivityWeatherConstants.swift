import Foundation

enum ActivityWeatherConstants {
    static let forecastURL = "https://api.open-meteo.com/v1/forecast"
    static let archiveURL = "https://archive-api.open-meteo.com/v1/archive"
    static let fields = "temperature_2m,dew_point_2m,wind_speed_10m,wind_direction_10m,shortwave_radiation"
    static let windUnit = "ms"
    static let version = 2
    static let timezone = "GMT"
    static let forecastHistoryDays = 85
    static let backfillDays = 120.0
    static let requestsPerRefresh = 40
    static let retryInterval: TimeInterval = 6 * 3600
    static let secondsPerDay: TimeInterval = 86_400
    static let secondsPerHour: TimeInterval = 3600
    static let hourFormat = "yyyy-MM-dd'T'HH:mm"
    static let dayFormat = "yyyy-MM-dd"
    static let keySeparator = "|"
}
