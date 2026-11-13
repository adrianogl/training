import Foundation
import Testing
@testable import RemoteSync

@Suite struct RemoteClientTests {
    private static let keys = try! RemoteKeys(syncKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")
    private static let baseURL = URL(string: "https://sync.example.test")!

    private func client(_ transport: ScriptedTransport) -> RemoteClient {
        RemoteClient(baseURL: Self.baseURL, keys: Self.keys, transport: transport)
    }

    @Test func createAccountAcceptsCreatedAndExisting() async throws {
        let transport = ScriptedTransport([.json(201, "{}"), .json(200, "{}")])

        try await client(transport).createAccount()
        try await client(transport).createAccount()

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://sync.example.test/api/v1/account")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer M9jNxgbJ9wEyyyGJTzrDGTbjcEa8kudkDe3tjwXqEco")
    }

    @Test func deleteAccountExpectsNoContent() async throws {
        let transport = ScriptedTransport([.json(204, "")])

        try await client(transport).deleteAccount()

        #expect(transport.requests.first?.httpMethod == "DELETE")
        #expect(transport.requests.first?.url?.path == "/api/v1/account")
    }

    @Test func changesSendsCursorAndDecodesPage() async throws {
        let body = #"{"records":[{"kind":"decision","id":"42","updatedAt":"2027-01-15T08:00:00.123Z","deleted":true,"payload":null,"seq":7}],"cursor":7,"hasMore":true}"#
        let transport = ScriptedTransport([.json(200, body)])

        let page = try await client(transport).changes(since: 3)

        #expect(transport.requests.first?.httpMethod == "GET")
        #expect(transport.requests.first?.url?.absoluteString == "https://sync.example.test/api/v1/changes?since=3")
        #expect(page.cursor == 7)
        #expect(page.hasMore)
        let record = try #require(page.records.first)
        #expect(record.kind == .decision)
        #expect(record.id == "42")
        #expect(record.deleted)
        #expect(record.payload == nil)
        #expect(record.seq == 7)
        #expect(RemoteTimestamp.milliseconds(record.updatedAt) == 1_800_000_000_123)
    }

    @Test func pushSendsContractBody() async throws {
        let transport = ScriptedTransport([.json(200, #"{"cursor":9,"ignored":[{"kind":"race","id":"A"}]}"#)])
        let record = RemoteRecord(kind: .race, id: "A", updatedAt: Date(timeIntervalSince1970: 1_800_000_000.5), deleted: false, payload: "cifra")

        let result = try await client(transport).push([record])

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v1/changes")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body == #"{"records":[{"deleted":false,"id":"A","kind":"race","payload":"cifra","updatedAt":"2027-01-15T08:00:00.500Z"}]}"#)
        #expect(result == RemotePushResult(cursor: 9, ignored: [RemoteRecordKey(kind: .race, id: "A")]))
    }

    @Test func mapsErrorStatuses() async throws {
        let cases: [(Int, RemoteSyncError)] = [
            (401, .unauthorized), (429, .rateLimited), (400, .badRequest), (413, .payloadTooLarge),
            (500, .server(status: 500)), (404, .unexpectedStatus(404)),
        ]
        for (status, expected) in cases {
            let transport = ScriptedTransport([.json(status, #"{"error":"x"}"#)])
            await #expect(throws: expected) { try await client(transport).changes(since: 0) }
        }
    }

    @Test func quotaExceededIsDistinctFromBodyTooLarge() async {
        let quota = ScriptedTransport([.json(413, #"{"error":"quota_exceeded"}"#)])
        let body = ScriptedTransport([.json(413, #"{"error":"body_too_large"}"#)])

        await #expect(throws: RemoteSyncError.quotaExceeded) { try await client(quota).push([]) }
        await #expect(throws: RemoteSyncError.payloadTooLarge) { try await client(body).push([]) }
    }

    @Test func malformedBodyIsDecodingError() async {
        let transport = ScriptedTransport([.json(200, "{}")])

        await #expect(throws: RemoteSyncError.decoding) { try await client(transport).changes(since: 0) }
    }
}
