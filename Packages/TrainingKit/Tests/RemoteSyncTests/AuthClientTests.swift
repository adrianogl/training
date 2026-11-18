import Foundation
import Testing
@testable import RemoteSync

@Suite struct AuthClientTests {
    private static let baseURL = URL(string: "https://sync.example.test")!
    private static let userJSON = #"{"email":"atleta@exemplo.com","name":"Atleta","emailVerified":false}"#

    @Test func signupSendsLegacyKeyAndReturnsSession() async throws {
        let transport = ScriptedTransport([.json(201, #"{"token":"abc","user":\#(Self.userJSON)}"#)])

        let session = try await AuthClient(baseURL: Self.baseURL, transport: transport)
            .signup(name: "Atleta", email: "atleta@exemplo.com", password: "corrida-longa-42", device: "iPhone", legacyKey: "legado")

        let request = try #require(transport.requests.first)
        let body = try JSONDecoder().decode([String: String].self, from: try #require(request.httpBody))
        #expect(request.url?.path == "/api/v1/auth/signup")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(body["legacyKey"] == "legado")
        #expect(session == AuthSession(token: "abc", user: AuthUser(email: "atleta@exemplo.com", name: "Atleta", emailVerified: false)))
    }

    @Test func signupSendsInviteToken() async throws {
        let transport = ScriptedTransport([.json(201, #"{"token":"abc","user":\#(Self.userJSON)}"#)])

        _ = try await AuthClient(baseURL: Self.baseURL, transport: transport)
            .signup(name: "Atleta", email: "atleta@exemplo.com", password: "corrida-longa-42", device: "iPhone", legacyKey: nil, inviteToken: "convite")

        let body = try JSONDecoder().decode([String: String].self, from: try #require(transport.requests.first?.httpBody))
        #expect(body["inviteToken"] == "convite")
        #expect(body["legacyKey"] == nil)
    }

    @Test func invitePreviewReadsNameEmailAndExpiry() async throws {
        let body = #"{"name":"Marina","email":"marina@exemplo.com","inviterName":"Adriano","expiresAt":"2026-11-25T12:00:00.000Z","appAccess":false}"#
        let transport = ScriptedTransport([.json(200, body)])

        let preview = try await AuthClient(baseURL: Self.baseURL, transport: transport).invitePreview(token: "tok")

        #expect(transport.requests.first?.url?.path == "/api/v1/invites/preview")
        #expect(transport.requests.first?.url?.query == "c=tok")
        #expect(preview.name == "Marina")
        #expect(preview.email == "marina@exemplo.com")
        #expect(preview.inviterName == "Adriano")
    }

    @Test func meReadsTheAdminFlag() async throws {
        let transport = ScriptedTransport([.json(200, #"{"user":{"email":"a@b.com","name":"A","emailVerified":true,"role":"member","admin":true}}"#)])

        let user = try await AuthClient(baseURL: Self.baseURL, token: "sessao", transport: transport).me()

        #expect(user.isAdmin)
    }

    @Test func authenticatedCallsSendTheSessionToken() async throws {
        let transport = ScriptedTransport([.json(200, #"{"user":\#(Self.userJSON)}"#)])

        _ = try await AuthClient(baseURL: Self.baseURL, token: "sessao", transport: transport).me()

        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer sessao")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "X-Training-Client") == "app")
    }

    @Test func sessionsDecodeDates() async throws {
        let body = #"{"sessions":[{"id":"s1","device":"iPad","lastSeenAt":"2026-11-14T12:00:00.000Z","current":true}]}"#
        let transport = ScriptedTransport([.json(200, body)])

        let sessions = try await AuthClient(baseURL: Self.baseURL, token: "sessao", transport: transport).sessions()

        #expect(sessions.map(\.device) == ["iPad"])
        #expect(sessions.first?.current == true)
    }

    @Test func endSessionPassesTheId() async throws {
        let transport = ScriptedTransport([.json(204, "")])

        try await AuthClient(baseURL: Self.baseURL, token: "sessao", transport: transport).endSession(id: "s2")

        #expect(transport.requests.first?.httpMethod == "DELETE")
        #expect(transport.requests.first?.url?.query == "id=s2")
    }

    @Test func serverErrorsMapToAuthErrors() {
        #expect(AuthClient.error(status: 401, body: Data(#"{"error":"invalid_credentials"}"#.utf8)) == .invalidCredentials)
        #expect(AuthClient.error(status: 409, body: Data(#"{"error":"email_taken"}"#.utf8)) == .emailTaken)
        #expect(AuthClient.error(status: 503, body: Data(#"{"error":"mail_unavailable"}"#.utf8)) == .mailUnavailable)
        #expect(AuthClient.error(status: 400, body: Data(#"{"error":"invalid_invite"}"#.utf8)) == .invalidInvite)
        #expect(AuthClient.error(status: 403, body: Data(#"{"error":"invite_required"}"#.utf8)) == .inviteRequired)
        #expect(AuthClient.error(status: 401, body: Data()) == .unauthorized)
        #expect(AuthClient.error(status: 500, body: Data()) == .server(status: 500))
    }
}
