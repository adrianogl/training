import MapKit
import FITReader
import Foundation
import Metrics
import TrainingCore

enum RaceWeatherLookup {
    private typealias C = RaceWeatherConstants

    static func reading(
        day: Day, startTime: String?, gpx: Data?, city: String?, predictionSeconds: Double, today: Day,
        session: URLSession = URLSession(configuration: .ephemeral)
    ) async -> RaceWeatherReading? {
        guard let startMinutes = minutes(startTime), predictionSeconds > 0, today <= day,
              let coordinate = await coordinate(gpx: gpx, city: city) else { return nil }
        let key = RaceWeatherKey(
            latitude: PlannedWeather.rounded(coordinate.lat), longitude: PlannedWeather.rounded(coordinate.lon), day: day,
            startMinutes: startMinutes, durationMinutes: Int(predictionSeconds / C.secondsPerMinute)
        )
        let forecast = today.days(until: day) < C.forecastDaysAhead
        if let cached = await RaceWeatherCache.shared.value(for: key) {
            return cached.flatMap { reading($0, source: forecast ? .forecast : .typical, key: key, predictionSeconds: predictionSeconds) }
        }
        let weather = forecast
            ? await average(day: day, key: key, archive: false, session: session)
            : await typical(day: day, key: key, session: session)
        await RaceWeatherCache.shared.store(weather, for: key, ttl: forecast ? C.forecastTTL : C.typicalTTL)
        return weather.flatMap { reading($0, source: forecast ? .forecast : .typical, key: key, predictionSeconds: predictionSeconds) }
    }

    static func minutes(_ startTime: String?) -> Int? {
        guard let parts = startTime?.split(separator: C.timeSeparator), parts.count >= 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]), (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * C.minutesPerHour + minute
    }

    private static func reading(_ weather: RunWeather, source: RaceWeatherSource, key: RaceWeatherKey, predictionSeconds: Double) -> RaceWeatherReading? {
        guard let effect = WeatherAdjustment.effect(weather) else { return nil }
        let end = key.startMinutes + key.durationMinutes
        return RaceWeatherReading(
            effect: effect, source: source, startHour: key.startMinutes / C.minutesPerHour,
            endHour: (end + C.minutesPerHour - 1) / C.minutesPerHour, predictionSeconds: predictionSeconds
        )
    }

    private static func typical(day: Day, key: RaceWeatherKey, session: URLSession) async -> RunWeather? {
        var years: [RunWeather] = []
        for offset in 1...C.typicalYears {
            let past = Day(year: day.year - offset, month: day.month, day: day.day)
            guard past.month == day.month, let weather = await average(day: past, key: key, archive: true, session: session) else { continue }
            years.append(weather)
        }
        guard !years.isEmpty else { return nil }
        let dewPoints = years.compactMap(\.dewPoint)
        return RunWeather(
            temperature: years.reduce(0) { $0 + $1.temperature } / Double(years.count),
            dewPoint: dewPoints.isEmpty ? nil : dewPoints.reduce(0, +) / Double(dewPoints.count)
        )
    }

    private static func average(day: Day, key: RaceWeatherKey, archive: Bool, session: URLSession) async -> RunWeather? {
        let request = WeatherRequest(latitude: key.latitude, longitude: key.longitude, firstDay: day.iso, lastDay: day.iso, archive: archive)
        guard let url = ActivityWeather.url(request, timezone: C.timezone),
              let hours = await ActivityWeather.fetch(url: url, session: session),
              let midnight = hours.first.map({ ActivityWeather.gmtCalendar.startOfDay(for: $0.start) }) else { return nil }
        let start = midnight.addingTimeInterval(Double(key.startMinutes) * C.secondsPerMinute)
        let end = start.addingTimeInterval(Double(key.durationMinutes) * C.secondsPerMinute)
        return ActivityWeather.average(hours, start: start, end: end)
    }

    private static func coordinate(gpx: Data?, city: String?) async -> Coordinate? {
        if let gpx, let start = gpxStart(gpx) { return start }
        guard let city = city?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty,
              let request = MKGeocodingRequest(addressString: city),
              let location = try? await request.mapItems.first?.location else { return nil }
        return Coordinate(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
    }
}

actor RaceWeatherCache {
    static let shared = RaceWeatherCache()
    private var entries: [RaceWeatherKey: (weather: RunWeather?, expires: Date)] = [:]

    func value(for key: RaceWeatherKey) -> RunWeather?? {
        guard let entry = entries[key], entry.expires > .now else { return nil }
        return .some(entry.weather)
    }

    func store(_ weather: RunWeather?, for key: RaceWeatherKey, ttl: TimeInterval) {
        entries[key] = (weather, Date.now.addingTimeInterval(ttl))
    }
}
