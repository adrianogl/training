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

extension ActivityRecord {
    public func weatherEffect(hotSessions: [Int64: Int]) -> WeatherEffect? {
        WeatherAdjustment.effect(runWeather, hotSessions: hotSessions[activityId] ?? 0)
    }

    public static func hotSessionCounts(_ records: [ActivityRecord]) -> [Int64: Int] {
        let runs = records.filter { ActivityTypeKey.isRun($0.typeKey) }.sorted { $0.start < $1.start }
        let window = Double(RunWeatherConstants.adaptationWindowDays) * 86_400
        var prefix = [0]
        prefix.reserveCapacity(runs.count + 1)
        for run in runs { prefix.append(prefix[prefix.count - 1] + (WeatherAdjustment.isHotSession(run.runWeather) ? 1 : 0)) }
        var counts: [Int64: Int] = [:]
        var lower = 0
        var upper = 0
        for run in runs {
            let since = run.start.addingTimeInterval(-window)
            while lower < runs.count, runs[lower].start < since { lower += 1 }
            while upper < runs.count, runs[upper].start < run.start { upper += 1 }
            counts[run.activityId] = max(prefix[upper] - prefix[min(lower, upper)], 0)
        }
        return counts
    }
}
