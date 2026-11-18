import Foundation
import Testing
@testable import RemoteSync

@Suite struct AdminClientTests {
    private static let baseURL = URL(string: "https://sync.example.test")!
    private static let inviteJSON = #"{"id":"i1","name":"Marina","email":"marina@exemplo.com","channel":"email","status":"pending","createdAt":"2026-11-18T12:00:00.000Z","expiresAt":"2026-11-25T12:00:00.000Z","acceptedAt":null,"appAccess":false}"#

    @Test func snapshotDecodesCountsInvitesUsersAndRequests() async throws {
        let body = """
        {"overview":{"accounts":4,"maxAccounts":20,"pendingInvites":1,"expiringInvites":0,"activeAccounts":2,"garminConnected":2,"requests24h":10,"errors24h":0,"requestsByHour":[],"requestsByRoute":[],"databaseBytes":null},
         "users":[{"id":"u1","name":"Thaís","email":"t@exemplo.com","role":"guest","admin":false,"appAccess":true,"garminConnected":true,"lastSeenAt":null,"dataBytes":1200}],
         "invites":[\(Self.inviteJSON)],
         "requests":[{"id":"r1","name":"Rafael","email":"rafa@exemplo.com","watch":"Forerunner","message":"Oi","createdAt":"2026-11-17T12:00:00.000Z"}]}
        """
        let transport = ScriptedTransport([.json(200, body)])

        let snapshot = try await AdminClient(baseURL: Self.baseURL, token: "sessao", transport: transport).snapshot()

        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer sessao")
        #expect(snapshot.overview == AdminCounts(accounts: 4, maxAccounts: 20, pendingInvites: 1))
        #expect(snapshot.users.first?.garminConnected == true)
        #expect(snapshot.invites.first?.status == .pending)
        #expect(snapshot.requests.first?.name == "Rafael")
    }

    @Test func createInviteDropsEmailOutsideTheEmailChannel() async throws {
        let transport = ScriptedTransport([.json(200, #"{"invite":\#(Self.inviteJSON),"link":"https://training.aglv.dev/convite?c=x","message":"Oi","mailed":false}"#)])

        let delivery = try await AdminClient(baseURL: Self.baseURL, token: "sessao", transport: transport)
            .createInvite(name: "Marina", channel: .whatsapp, email: "marina@exemplo.com")

        let body = try JSONDecoder().decode([String: String].self, from: try #require(transport.requests.first?.httpBody))
        #expect(transport.requests.first?.url?.path == "/api/v1/admin/invites")
        #expect(body == ["name": "Marina", "channel": "whatsapp"])
        #expect(delivery.link.hasSuffix("c=x"))
    }

    @Test func actionsSendIdAndAction() async throws {
        let transport = ScriptedTransport([.json(200, #"{"invite":\#(Self.inviteJSON)}"#), .json(200, #"{"id":"r1","status":"declined"}"#), .json(204, "")])
        let client = AdminClient(baseURL: Self.baseURL, token: "sessao", transport: transport)

        try await client.cancelInvite(id: "i1")
        try await client.declineRequest(id: "r1")
        try await client.deleteUser(id: "u1")

        let bodies = try transport.requests.prefix(2).map { try JSONDecoder().decode([String: String].self, from: try #require($0.httpBody)) }
        #expect(bodies == [["id": "i1", "action": "cancel"], ["id": "r1", "action": "decline"]])
        #expect(transport.requests.map { $0.url?.path } == ["/api/v1/admin/invites/action", "/api/v1/admin/invite-requests/action", "/api/v1/admin/users"])
        #expect(transport.requests.last?.url?.query == "id=u1")
    }
}
