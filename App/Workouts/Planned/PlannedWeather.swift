import FITReader
import Foundation
import Storage
import SwiftData
import TrainingCore

struct OpenMeteoResponse: Decodable {
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double?]
        let dew_point_2m: [Double?]
    }

    let hourly: Hourly
}

enum PlannedWeather {
    private typealias C = PlannedExtrasConstants

    static func morning(day: Day, coordinate: Coordinate, session: URLSession = URLSession(configuration: .ephemeral)) async -> [HourlyWeather] {
        guard let url = url(day: day, coordinate: coordinate),
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return parse(data)
    }

    static func url(day: Day, coordinate: Coordinate) -> URL? {
        var components = URLComponents(string: C.forecastURL)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: rounded(coordinate.lat)),
            URLQueryItem(name: "longitude", value: rounded(coordinate.lon)),
            URLQueryItem(name: "hourly", value: C.forecastFields),
            URLQueryItem(name: "timezone", value: C.forecastTimezone),
            URLQueryItem(name: "start_date", value: day.iso),
            URLQueryItem(name: "end_date", value: day.iso),
        ]
        return components?.url
    }

    static func parse(_ data: Data) -> [HourlyWeather] {
        guard let response = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else { return [] }
        let hourly = response.hourly
        return hourly.time.indices.compactMap { index in
            guard index < hourly.temperature_2m.count, let temperature = hourly.temperature_2m[index],
                  let hour = Int(hourly.time[index].suffix(5).prefix(2)),
                  (C.morningStartHour..<C.morningEndHour).contains(hour) else { return nil }
            let dewPoint = index < hourly.dew_point_2m.count ? hourly.dew_point_2m[index] : nil
            return HourlyWeather(hour: hour, temperature: temperature, dewPoint: dewPoint)
        }
    }

    static func rounded(_ value: Double) -> String {
        String(format: "%.1f", (value * C.coordinateScale).rounded() / C.coordinateScale)
    }

    static func lastRunStart(context: ModelContext) -> Coordinate? {
        var descriptor = FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)])
        descriptor.fetchLimit = C.locationSearchLimit
        let records = (try? context.fetch(descriptor)) ?? []
        for record in records where ActivityTypeKey.isRun(record.typeKey) {
            if let data = record.routeData, let first = (try? JSONDecoder().decode([Coordinate].self, from: data))?.first {
                return first
            }
        }
        return nil
    }
}
