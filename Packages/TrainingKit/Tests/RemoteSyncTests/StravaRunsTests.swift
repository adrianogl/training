import Foundation
import Testing
@testable import RemoteSync

@Suite struct StravaRunsTests {
    private func client(_ transport: ScriptedTransport) -> StravaClient {
        StravaClient(baseURL: URL(string: "https://sync.example.test")!, token: "sessao", transport: transport)
    }

    private let body = #"{"runs":[{"id":11,"name":"Longão","sportType":"Run","startDate":"2026-09-12T10:05:00Z","startDateLocal":"2026-09-12T07:05:00Z","distanceMeters":18200,"movingSeconds":5700,"elapsedSeconds":5900,"elevationGain":120,"averageHeartRate":148,"maxHeartRate":165,"hasGps":true,"deviceName":"Strava iPhone App"},{"id":12,"name":"Esteira","sportType":"Run","startDate":"2026-07-07T22:00:00Z","startDateLocal":"2026-07-07T19:00:00Z","distanceMeters":8000,"movingSeconds":2520,"elapsedSeconds":2520,"elevationGain":null,"averageHeartRate":null,"maxHeartRate":null,"hasGps":false,"deviceName":null}]}"#

    @Test func runsAsksThePeriodAndDecodes() async throws {
        let transport = ScriptedTransport([.json(200, body)])
        let after = Date(timeIntervalSince1970: 1_750_000_000)
        let before = Date(timeIntervalSince1970: 1_780_000_000)

        let runs = try await client(transport).runs(after: after, before: before)
        let query = transport.requests.first?.url?.query() ?? ""

        #expect(runs.map(\.id) == [11, 12])
        #expect(runs[0].localDayISO == "2026-09-12")
        #expect(runs[0].averageHeartRate == 148)
        #expect(runs[1].averageHeartRate == nil && !runs[1].hasGps)
        #expect(query.contains("after=\(RemoteTimestamp.string(from: after))"))
        #expect(transport.requests.first?.url?.path() == "/api/v1/strava/runs")
    }

    @Test func rateLimitBecomesRetryLater() async {
        let transport = ScriptedTransport([.json(200, #"{"status":"retry_later"}"#)])

        await #expect(throws: StravaLinkError.retryLater) {
            try await client(transport).runs(after: .distantPast, before: .now)
        }
    }

    @Test func runsWithAGarminTwinAreDropped() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let run = StravaRunCandidate(
            id: 1, name: "", sportType: "Run", start: start, startLocal: "2026-09-12T07:05:00Z", distanceMeters: 10_000, movingSeconds: 3_000,
            elapsedSeconds: 3_000, elevationGain: nil, averageHeartRate: nil, maxHeartRate: nil, hasGps: true
        )

        #expect(StravaRunMatching.unmatched([run], existing: [(start.addingTimeInterval(600), 10_500)]).isEmpty)
        #expect(StravaRunMatching.unmatched([run], existing: [(start.addingTimeInterval(1_200), 10_000)]) == [run])
        #expect(StravaRunMatching.unmatched([run], existing: [(start, 12_000)]) == [run])
    }
}
