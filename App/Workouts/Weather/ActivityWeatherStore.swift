import FITReader
import Foundation
import Storage
import SwiftData
import TrainingCore

enum ActivityWeatherStore {
    private typealias C = ActivityWeatherConstants

    static func refresh(container: ModelContainer, now: Date = .now) async {
        let context = ModelContext(container)
        let session = URLSession(configuration: .ephemeral)
        let pending = candidates(in: context, now: now)
        guard !pending.isEmpty else { return }
        var cache: [WeatherRequest: [WeatherHour]?] = [:]
        for item in pending {
            if cache[item.request] == nil {
                guard cache.count < C.requestsPerRefresh else { break }
                cache[item.request] = .some(await ActivityWeather.fetch(item.request, session: session))
            }
            let hours = cache[item.request] ?? nil
            item.record.weatherCheckedAt = now
            guard let hours, let weather = ActivityWeather.average(hours, start: item.start, end: item.end) else { continue }
            item.record.weatherTemperature = weather.temperature
            item.record.weatherDewPoint = weather.dewPoint
            item.record.weatherWindSpeed = weather.windSpeed
            item.record.weatherWindFrom = weather.windFrom
            item.record.weatherRadiation = weather.radiation
            item.record.weatherVersion = C.version
        }
        try? context.save()
    }

    private static func candidates(in context: ModelContext, now: Date) -> [(record: ActivityRecord, request: WeatherRequest, start: Date, end: Date)] {
        let since = now.addingTimeInterval(-C.backfillDays * C.secondsPerDay)
        let version = C.version
        let descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.start >= since && $0.weatherVersion < version },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { record in
            guard ActivityTypeKey.isRun(record.typeKey),
                  record.weatherTemperature != nil || (record.weatherCheckedAt.map({ now.timeIntervalSince($0) >= C.retryInterval }) ?? true),
                  let coordinate = startCoordinate(record) else { return nil }
            let end = record.start.addingTimeInterval(record.duration ?? record.movingDuration ?? 0)
            guard end <= now else { return nil }
            return (record, ActivityWeather.request(coordinate: coordinate, start: record.start, end: end, now: now), record.start, end)
        }
    }

    private static func startCoordinate(_ record: ActivityRecord) -> Coordinate? {
        guard let data = record.routeData else { return nil }
        return (try? JSONDecoder().decode([Coordinate].self, from: data))?.first
    }
}
