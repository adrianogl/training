import Foundation
import GarminAPI

public struct StravaClient: Sendable {
    private let baseURL: URL
    private let token: String
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: String, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    public func connectURL() async throws -> URL {
        try JSONDecoder().decode(StravaConnectBody.self, from: try await send("GET", "api/v1/strava/connect")).url
    }

    public func status() async throws -> StravaStatus {
        try status(from: try await send("GET", "api/v1/strava"))
    }

    public func setEnabled(_ enabled: Bool) async throws -> StravaStatus {
        try status(from: try await send("PATCH", "api/v1/strava", body: ["enabled": enabled]))
    }

    public func disconnect() async throws {
        _ = try await send("DELETE", "api/v1/strava", accepted: [204])
    }

    public func describe(_ request: StravaDescribeRequest) async throws -> StravaDescribeOutcome {
        let body: [String: any Sendable] = [
            "activityId": request.activityId,
            "startTime": RemoteTimestamp.string(from: request.startTime),
            "elapsedSeconds": request.elapsedSeconds,
            "distanceMeters": request.distanceMeters,
            "text": request.text,
        ]
        let data = try await send("POST", "api/v1/strava/describe", body: body)
        guard let outcome = StravaDescribeOutcome(rawValue: try JSONDecoder().decode(StravaDescribeBody.self, from: data).status) else {
            throw StravaLinkError.unavailable
        }
        return outcome
    }

    public func runs(after: Date, before: Date) async throws -> [StravaRunCandidate] {
        let query = "after=\(RemoteTimestamp.string(from: after))&before=\(RemoteTimestamp.string(from: before))"
        let body = try JSONDecoder().decode(StravaRunsBody.self, from: try await send("GET", "api/v1/strava/runs", query: query))
        guard let runs = body.runs else { throw body.status == StravaRunMatchingConstants.retryLater ? StravaLinkError.retryLater : StravaLinkError.unavailable }
        return runs.compactMap { run in
            guard let start = RemoteTimestamp.date(from: run.startDate) else { return nil }
            return StravaRunCandidate(
                id: run.id, name: run.name, sportType: run.sportType, start: start, startLocal: run.startDateLocal,
                distanceMeters: run.distanceMeters, movingSeconds: run.movingSeconds, elapsedSeconds: run.elapsedSeconds,
                elevationGain: run.elevationGain, averageHeartRate: run.averageHeartRate, maxHeartRate: run.maxHeartRate, hasGps: run.hasGps
            )
        }
    }

    private func status(from data: Data) throws -> StravaStatus {
        let body = try JSONDecoder().decode(StravaStatusBody.self, from: data)
        return StravaStatus(connected: body.connected, athleteName: body.athleteName ?? "", format: body.format ?? "B", enabled: body.enabled ?? false)
    }

    private func send(
        _ method: String, _ path: String, query: String? = nil, body: [String: any Sendable]? = nil, accepted: Set<Int> = [200]
    ) async throws -> Data {
        var url = baseURL.appending(path: path)
        if let query, let withQuery = URL(string: url.absoluteString + "?" + query) { url = withQuery }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport.send(request)
        guard accepted.contains(response.statusCode) else { throw Self.error(status: response.statusCode, body: data) }
        return data
    }

    static func error(status: Int, body: Data) -> StravaLinkError {
        switch (try? JSONDecoder().decode(StravaErrorBody.self, from: body))?.error {
        case "strava_not_configured": return .notConfigured
        case "strava_not_connected": return .notConnected
        case "strava_session_expired": return .sessionExpired
        case "strava_unavailable", "storage_unavailable": return .unavailable
        default: return status == 401 ? .unauthorized : .server(status: status)
        }
    }
}
