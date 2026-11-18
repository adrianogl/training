import Foundation
import TrainingCore

extension ActivityRecord {
    public var runWeather: RunWeather? {
        weatherTemperature.map {
            RunWeather(temperature: $0, dewPoint: weatherDewPoint, windSpeed: weatherWindSpeed, windFrom: weatherWindFrom, radiation: weatherRadiation)
        }
    }

    public var weatherEffect: WeatherEffect? {
        WeatherAdjustment.effect(runWeather)
    }

    public func weatherEffect(among runs: [ActivityRecord]) -> WeatherEffect? {
        WeatherAdjustment.effect(runWeather, hotSessions: hotSessions(among: runs))
    }

    public func hotSessions(among runs: [ActivityRecord]) -> Int {
        let since = start.addingTimeInterval(-Double(RunWeatherConstants.adaptationWindowDays) * 86_400)
        return runs.filter { other in
            other.activityId != activityId && other.start >= since && other.start < start
                && ActivityTypeKey.isRun(other.typeKey) && WeatherAdjustment.isHotSession(other.runWeather)
        }.count
    }
}
