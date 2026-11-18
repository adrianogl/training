import FITReader
import Foundation
import TrainingCore

enum ActivityWeather {
    private typealias C = ActivityWeatherConstants

    static func request(coordinate: Coordinate, start: Date, end: Date, now: Date) -> WeatherRequest {
        let archive = now.timeIntervalSince(start) > Double(C.forecastHistoryDays) * C.secondsPerDay
        return WeatherRequest(
            latitude: PlannedWeather.rounded(coordinate.lat),
            longitude: PlannedWeather.rounded(coordinate.lon),
            firstDay: dayFormatter.string(from: start),
            lastDay: dayFormatter.string(from: end),
            archive: archive
        )
    }

    static func url(_ request: WeatherRequest, timezone: String = C.timezone) -> URL? {
        var components = URLComponents(string: request.archive ? C.archiveURL : C.forecastURL)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: request.latitude),
            URLQueryItem(name: "longitude", value: request.longitude),
            URLQueryItem(name: "hourly", value: C.fields),
            URLQueryItem(name: "timezone", value: timezone),
            URLQueryItem(name: "start_date", value: request.firstDay),
            URLQueryItem(name: "end_date", value: request.lastDay),
        ]
        return components?.url
    }

    static func fetch(_ request: WeatherRequest, session: URLSession) async -> [WeatherHour]? {
        guard let url = url(request) else { return nil }
        return await fetch(url: url, session: session)
    }

    static func fetch(url: URL, session: URLSession) async -> [WeatherHour]? {
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return parse(data)
    }

    static func parse(_ data: Data) -> [WeatherHour]? {
        guard let response = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else { return nil }
        let hourly = response.hourly
        return hourly.time.indices.compactMap { index in
            guard index < hourly.temperature_2m.count, let temperature = hourly.temperature_2m[index],
                  let start = hourFormatter.date(from: hourly.time[index]) else { return nil }
            let dewPoint = index < hourly.dew_point_2m.count ? hourly.dew_point_2m[index] : nil
            return WeatherHour(start: start, temperature: temperature, dewPoint: dewPoint)
        }
    }

    static func average(_ hours: [WeatherHour], start: Date, end: Date) -> RunWeather? {
        let finish = max(end, start.addingTimeInterval(1))
        var weight = 0.0
        var temperature = 0.0
        var dewWeight = 0.0
        var dewPoint = 0.0
        for hour in hours {
            let overlap = min(finish, hour.start.addingTimeInterval(C.secondsPerHour)).timeIntervalSince(max(start, hour.start))
            guard overlap > 0 else { continue }
            weight += overlap
            temperature += hour.temperature * overlap
            if let dew = hour.dewPoint {
                dewWeight += overlap
                dewPoint += dew * overlap
            }
        }
        guard weight > 0 else { return nil }
        return RunWeather(temperature: temperature / weight, dewPoint: dewWeight > 0 ? dewPoint / dewWeight : nil)
    }

    static let gmtCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: C.timezone) ?? .gmt
        return calendar
    }()

    private static let hourFormatter: DateFormatter = formatter(C.hourFormat)
    private static let dayFormatter: DateFormatter = formatter(C.dayFormat)

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: C.timezone)
        formatter.dateFormat = format
        return formatter
    }
}
