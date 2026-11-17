import Foundation
import Testing
@testable import RemoteSync

@Suite struct StravaClientTests {
    private func client(_ transport: ScriptedTransport) -> StravaClient {
        StravaClient(baseURL: URL(string: "https://sync.example.test")!, token: "sessao", transport: transport)
    }

    @Test func connectURLReadsTheAuthorizeAddress() async throws {
        let transport = ScriptedTransport([.json(200, #"{"url":"https://www.strava.com/oauth/authorize?state=x"}"#)])

        let url = try await client(transport).connectURL()

        #expect(url.host() == "www.strava.com")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer sessao")
    }

    @Test func statusAndToggleDecode() async throws {
        let transport = ScriptedTransport([
            .json(200, #"{"connected":true,"athleteName":"Adriano G","format":"B","enabled":true}"#),
            .json(200, #"{"connected":true,"athleteName":"Adriano G","format":"B","enabled":false}"#),
        ])

        let status = try await client(transport).status()
        let off = try await client(transport).setEnabled(false)

        #expect(status == StravaStatus(connected: true, athleteName: "Adriano G", format: "B", enabled: true))
        #expect(off.enabled == false)
        #expect(transport.requests.last?.httpMethod == "PATCH")
    }

    @Test func describeSendsTheBodyAndMapsEveryOutcome() async throws {
        let outcomes = ["posted", "updated", "not_found", "edited_by_user", "disabled", "retry_later"]
        let transport = ScriptedTransport(outcomes.map { .json(200, #"{"status":"\#($0)"}"#) })
        let request = StravaDescribeRequest(
            activityId: "7",
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            elapsedSeconds: 2_700,
            distanceMeters: 10_000,
            text: "Rodagem | 10,0 km @ 4:30/km\nvia https://training.aglv.dev"
        )

        var results: [StravaDescribeOutcome] = []
        for _ in outcomes { results.append(try await client(transport).describe(request)) }

        #expect(results == [.posted, .updated, .notFound, .editedByUser, .disabled, .retryLater])
        let sent = try JSONSerialization.jsonObject(with: transport.requests[0].httpBody ?? Data()) as? [String: Any]
        #expect(sent?["activityId"] as? String == "7")
        #expect(sent?["startTime"] as? String == "2023-11-14T22:13:20.000Z")
        #expect(sent?["distanceMeters"] as? Double == 10_000)
    }

    @Test func errorsMapToLinkErrors() {
        #expect(StravaClient.error(status: 503, body: Data(#"{"error":"strava_not_configured"}"#.utf8)) == .notConfigured)
        #expect(StravaClient.error(status: 409, body: Data(#"{"error":"strava_session_expired"}"#.utf8)) == .sessionExpired)
        #expect(StravaClient.error(status: 401, body: Data()) == .unauthorized)
    }
}
