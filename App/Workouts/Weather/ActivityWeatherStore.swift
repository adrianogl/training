import FITReader
import Foundation
import Storage
import SwiftData
import TrainingCore

enum ActivityWeatherStore {
    private typealias C = ActivityWeatherConstants

    @discardableResult
    static func refresh(container: ModelContainer, now: Date = .now) async -> Set<Int64> {
        let context = ModelContext(container)
        let session = URLSession(configuration: .ephemeral)
        let pending = candidates(in: context, now: now)
        guard !pending.isEmpty else { return [] }
        var requests: [WeatherRequest] = []
        for item in pending where !requests.contains(item.request) && requests.count < C.requestsPerRefresh {
            requests.append(item.request)
        }
        let cache = await fetchAll(requests, session: session)
        var updated: Set<Int64> = []
        for item in pending {
            guard let fetched = cache[item.request] else { continue }
            let hours = fetched
            item.record.weatherCheckedAt = now
            guard let hours, let weather = ActivityWeather.average(hours, start: item.start, end: item.end) else { continue }
            item.record.weatherTemperature = weather.temperature
            item.record.weatherDewPoint = weather.dewPoint
            item.record.weatherWindSpeed = weather.windSpeed
            item.record.weatherWindFrom = weather.windFrom
            item.record.weatherRadiation = weather.radiation
            item.record.weatherVersion = C.version
            updated.insert(item.record.activityId)
        }
        try? context.save()
        return updated
    }

    private static func fetchAll(_ requests: [WeatherRequest], session: URLSession) async -> [WeatherRequest: [WeatherHour]?] {
        await withTaskGroup(of: (WeatherRequest, [WeatherHour]?).self) { group in
            var results: [WeatherRequest: [WeatherHour]?] = [:]
            var next = requests.makeIterator()
            for _ in 0..<C.parallelRequests {
                guard let request = next.next() else { break }
                group.addTask { (request, await ActivityWeather.fetch(request, session: session)) }
            }
            while let (request, hours) = await group.next() {
                results[request] = .some(hours)
                if let request = next.next() {
                    group.addTask { (request, await ActivityWeather.fetch(request, session: session)) }
                }
            }
            return results
        }
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
