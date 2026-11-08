import Foundation
import TrainingCore

public struct GarminClient: GarminDataSource {
    private let tokens: TokenProvider
    private let transport: any HTTPTransport
    private let baseURL: URL
    private let sleep: @Sendable (Duration) async throws -> Void
    private let now: @Sendable () -> Date

    public init(
        tokens: TokenProvider,
        transport: any HTTPTransport,
        baseURL: URL = GarminEndpoints.base,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.tokens = tokens
        self.transport = transport
        self.baseURL = baseURL
        self.sleep = sleep
        self.now = now
    }

    public func heartRateZones() async throws -> HRZonesDTO {
        let path = GarminEndpoints.heartRateZonesPath
        let data = try await get(path: path)
        let zones: [HRZonesDTO] = try decode(data, path: path)
        guard let zone = zones.first(where: { $0.sport == "DEFAULT" }) else {
            throw GarminAPIError.decoding(path: path)
        }
        return zone
    }

    public func dailySummaries(from: Day, to: Day) async throws -> [DailySummaryDTO] {
        try await ranged(from: from, to: to, maxDays: GarminEndpoints.dailySummariesMaxDays) { window in
            let path = GarminEndpoints.dailySummariesPath
            let query = [("startDate", window.lowerBound.iso), ("endDate", window.upperBound.iso)]
            return try self.decode(try await self.get(path: path, query: query), path: path, envelope: DataEnvelope<DailySummaryDTO>.self)
        }
    }

    public func hrvSummaries(from: Day, to: Day) async throws -> [HRVSummaryDTO] {
        try await ranged(from: from, to: to, maxDays: GarminEndpoints.hrvMaxDays) { window in
            let path = "\(GarminEndpoints.hrvPathPrefix)/\(window.lowerBound.iso)/\(window.upperBound.iso)"
            return try self.decode(try await self.get(path: path), path: path, envelope: HRVEnvelope.self)
        }
    }

    public func sleepSummaries(from: Day, to: Day) async throws -> [SleepDTO] {
        try await ranged(from: from, to: to, maxDays: GarminEndpoints.sleepMaxDays) { window in
            let path = GarminEndpoints.sleepPath
            let query = [("startDate", window.lowerBound.iso), ("endDate", window.upperBound.iso)]
            return try self.decode(try await self.get(path: path, query: query), path: path)
        }
    }

    public func bodyBattery(from: Day, to: Day) async throws -> [BodyBatteryDayDTO] {
        try await ranged(from: from, to: to, maxDays: GarminEndpoints.bodyBatteryMaxDays) { window in
            let path = GarminEndpoints.bodyBatteryPath
            let query = [("startDate", window.lowerBound.iso), ("endDate", window.upperBound.iso)]
            return try self.decode(try await self.get(path: path, query: query), path: path)
        }
    }

    public func activities(start: Int, limit: Int, from: Day?, to: Day?) async throws -> [ActivityDTO] {
        let path = GarminEndpoints.activitiesPath
        var query = [("start", String(start)), ("limit", String(limit))]
        if let from { query.append(("startDate", from.iso)) }
        if let to { query.append(("endDate", to.iso)) }
        return try decode(try await get(path: path, query: query), path: path)
    }

    public func fitArchive(activityId: Int64) async throws -> Data {
        try await get(path: "\(GarminEndpoints.fitDownloadPathPrefix)/\(activityId)", accept: "*/*")
    }

    private func ranged<T>(
        from: Day,
        to: Day,
        maxDays: Int,
        fetch: (ClosedRange<Day>) async throws -> [T]
    ) async throws -> [T] {
        var result: [T] = []
        for window in windows(from: from, to: to, maxDays: maxDays) {
            result += try await fetch(window)
        }
        return result
    }

    private func decode<T: Decodable>(_ data: Data, path: String) throws -> [T] {
        guard !data.isEmpty else { return [] }
        do {
            return try JSONDecoder().decode([LossyElement<T>].self, from: data).compactMap(\.value)
        } catch {
            throw GarminAPIError.decoding(path: path)
        }
    }

    private func decode<E: ListEnvelope>(_ data: Data, path: String, envelope: E.Type) throws -> [E.Element] {
        guard !data.isEmpty else { return [] }
        do {
            return try JSONDecoder().decode(E.self, from: data).elements.compactMap(\.value)
        } catch {
            throw GarminAPIError.decoding(path: path)
        }
    }

    private func get(path: String, query: [(String, String)] = [], accept: String = "application/json") async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        let url = components.url!
        var retries = 0
        var refreshedToken = false
        while true {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(accept, forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(try await tokens.bearer())", forHTTPHeaderField: "Authorization")
            let (data, response) = try await transport.send(request)
            let status = response.statusCode
            switch status {
            case 200..<300:
                return data
            case 401:
                guard !refreshedToken else { throw GarminAPIError.unauthorized }
                refreshedToken = true
                await tokens.invalidate()
            case 400:
                throw GarminAPIError.badRequest(path: path)
            case 406:
                throw GarminAPIError.notAcceptable
            case 429:
                let schedule = GarminEndpoints.rateLimitDelaysSeconds
                guard retries < schedule.count else { throw GarminAPIError.rateLimited(path: path) }
                let header = response.value(forHTTPHeaderField: GarminEndpoints.retryAfterHeader)
                try await sleep(.seconds(RetryAfter.seconds(from: header, now: now()) ?? schedule[retries]))
                retries += 1
            case 500..<600:
                let schedule = GarminEndpoints.retryDelaysSeconds
                guard retries < schedule.count else { throw GarminAPIError.server(status: status) }
                try await sleep(.seconds(schedule[retries]))
                retries += 1
            default:
                throw GarminAPIError.server(status: status)
            }
        }
    }
}
