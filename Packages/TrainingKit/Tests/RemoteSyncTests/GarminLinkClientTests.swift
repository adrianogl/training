import Foundation
import Testing
@testable import RemoteSync

@Suite struct GarminLinkClientTests {
    private func client(_ transport: ScriptedTransport) -> GarminLinkClient {
        GarminLinkClient(baseURL: URL(string: "https://sync.example.test")!, token: "sessao", transport: transport)
    }

    @Test func connectReturnsCodeStepAndVerifyConnects() async throws {
        let transport = ScriptedTransport([.json(200, #"{"status":"needs_code","method":"email"}"#), .json(200, #"{"status":"connected"}"#)])

        let first = try await client(transport).connect(email: "a@b.com", password: "x")
        let second = try await client(transport).verify(code: "123456")

        #expect(first == .needsCode(method: "email"))
        #expect(second == .connected)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer sessao")
    }

    @Test func sessionDecodesIntoGarminSession() async throws {
        let body = #"{"accessToken":"a","refreshToken":"r","clientId":"C","expiresAt":"2026-11-14T13:00:00.000Z"}"#
        let transport = ScriptedTransport([.json(200, body)])

        let session = try await client(transport).session()

        #expect(session.accessToken == "a")
        #expect(session.expiresAt == Date(timeIntervalSince1970: 1_794_661_200))
    }

    @Test func errorsMapToLinkErrors() {
        #expect(GarminLinkClient.error(status: 400, body: Data(#"{"error":"garmin_invalid_code"}"#.utf8)) == .invalidCode)
        #expect(GarminLinkClient.error(status: 404, body: Data(#"{"error":"garmin_not_connected"}"#.utf8)) == .notConnected)
        #expect(GarminLinkClient.error(status: 401, body: Data()) == .unauthorized)
    }
}
