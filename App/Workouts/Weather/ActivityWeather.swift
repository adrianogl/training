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
            URLQueryItem(name: "wind_speed_unit", value: C.windUnit),
            URLQueryItem(name: "timezone", value: timezone),
            URLQueryItem(name: "start_date", value: request.firstDay),
            URLQueryItem(name: "end_date", value: request.lastDay),
        ]
        return components?.url
    }

    static func fetch(_ request: WeatherRequest, session: URLSession) async -> WeatherFetch {
        guard let url = url(request) else { return .answered(nil) }
        return await answer(url: url, session: session)
    }

    static func fetch(url: URL, session: URLSession) async -> [WeatherHour]? {
        guard case .answered(let hours) = await answer(url: url, session: session) else { return nil }
        return hours
    }

    static func answer(url: URL, session: URLSession) async -> WeatherFetch {
        guard let (data, response) = try? await session.data(from: url) else { return .unreachable }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status >= ActivityWeatherConstants.serverErrorStatus { return .unreachable }
        guard status == ActivityWeatherConstants.okStatus else { return .answered(nil) }
        return .answered(parse(data))
    }

    static func parse(_ data: Data) -> [WeatherHour]? {
        guard let response = try? JSONDecoder().decode(ActivityWeatherResponse.self, from: data) else { return nil }
        let hourly = response.hourly
        func value(_ list: [Double?]?, _ index: Int) -> Double? {
            guard let list, index < list.count else { return nil }
            return list[index]
        }
        return hourly.time.indices.compactMap { index in
            guard let temperature = value(hourly.temperature_2m, index), let start = hourFormatter.date(from: hourly.time[index]) else { return nil }
            return WeatherHour(
                start: start, temperature: temperature, dewPoint: value(hourly.dew_point_2m, index),
                windSpeed: value(hourly.wind_speed_10m, index), windFrom: value(hourly.wind_direction_10m, index),
                radiation: value(hourly.shortwave_radiation, index)
            )
        }
    }

    static func average(_ hours: [WeatherHour], start: Date, end: Date) -> RunWeather? {
        let finish = max(end, start.addingTimeInterval(1))
        var weight = 0.0
        var temperature = 0.0
        var dewWeight = 0.0
        var dewPoint = 0.0
        var windWeight = 0.0
        var windSpeed = 0.0
        var windEast = 0.0
        var windNorth = 0.0
        var sunWeight = 0.0
        var radiation = 0.0
        for hour in hours {
            let overlap = min(finish, hour.start.addingTimeInterval(C.secondsPerHour)).timeIntervalSince(max(start, hour.start))
            guard overlap > 0 else { continue }
            weight += overlap
            temperature += hour.temperature * overlap
            if let dew = hour.dewPoint {
                dewWeight += overlap
                dewPoint += dew * overlap
            }
            if let speed = hour.windSpeed, let from = hour.windFrom {
                windWeight += overlap
                windSpeed += speed * overlap
                windEast += speed * sin(from * .pi / 180) * overlap
                windNorth += speed * cos(from * .pi / 180) * overlap
            }
            if let sun = hour.radiation {
                sunWeight += overlap
                radiation += sun * overlap
            }
        }
        guard weight > 0 else { return nil }
        let direction = windWeight > 0 ? (atan2(windEast, windNorth) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360) : nil
        return RunWeather(
            temperature: temperature / weight,
            dewPoint: dewWeight > 0 ? dewPoint / dewWeight : nil,
            windSpeed: windWeight > 0 ? windSpeed / windWeight : nil,
            windFrom: direction,
            radiation: sunWeight > 0 ? radiation / sunWeight : nil
        )
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
