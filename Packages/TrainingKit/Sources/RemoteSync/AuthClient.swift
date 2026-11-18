import Foundation
import GarminAPI

public struct AuthClient: Sendable {
    private typealias C = AuthConstants
    private let baseURL: URL
    private let token: String?
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: String? = nil, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    public func signup(name: String, email: String, password: String, device: String, legacyKey: String?, inviteToken: String? = nil) async throws -> AuthSession {
        var body: [String: String] = ["name": name, "email": email, "password": password, "device": device]
        if let legacyKey { body["legacyKey"] = legacyKey }
        if let inviteToken { body["inviteToken"] = inviteToken }
        return try decode(try await send("POST", C.signupPath, body: body, accepted: [201]))
    }

    public func login(email: String, password: String, device: String) async throws -> AuthSession {
        try decode(try await send("POST", C.loginPath, body: ["email": email, "password": password, "device": device]))
    }

    public func logout() async throws {
        _ = try await send("POST", C.logoutPath, accepted: [204])
    }

    public func me() async throws -> AuthUser {
        let envelope: AuthUserEnvelope = try decode(try await send("GET", C.mePath))
        return envelope.user
    }

    public func rename(_ name: String) async throws -> AuthUser {
        let envelope: AuthUserEnvelope = try decode(try await send("PATCH", C.mePath, body: ["name": name]))
        return envelope.user
    }

    public func changePassword(current: String, next: String, endOtherSessions: Bool) async throws {
        let body = PasswordChangeBody(current: current, next: next, endOtherSessions: endOtherSessions)
        _ = try await send("POST", C.passwordPath, data: try JSONEncoder().encode(body), accepted: [204])
    }

    public func forgotPassword(email: String) async throws {
        _ = try await send("POST", C.forgotPath, body: ["email": email], accepted: [204])
    }

    public func resetPassword(token resetToken: String, password: String) async throws {
        _ = try await send("POST", C.resetPath, body: ["token": resetToken, "password": password], accepted: [204])
    }

    public func verifyEmail(token verifyToken: String) async throws {
        _ = try await send("POST", C.verifyPath, body: ["token": verifyToken], accepted: [204])
    }

    public func invitePreview(token inviteToken: String) async throws -> InvitePreview {
        try decode(try await send("GET", C.invitePreviewPath, query: [URLQueryItem(name: C.inviteQuery, value: inviteToken)]))
    }

    public func resendVerification() async throws {
        _ = try await send("POST", C.resendVerificationPath, accepted: [204])
    }

    public func sessions() async throws -> [AuthSessionInfo] {
        let envelope: AuthSessionsEnvelope = try decode(try await send("GET", C.sessionsPath))
        return envelope.sessions
    }

    public func endSession(id: String) async throws {
        _ = try await send("DELETE", C.sessionsPath, query: [URLQueryItem(name: C.sessionIdQuery, value: id)], accepted: [204])
    }

    public func deleteAccount() async throws {
        _ = try await send("DELETE", C.accountPath, accepted: [204])
    }

    func send(_ method: String, _ path: String, body: [String: String]? = nil, accepted: Set<Int> = [200]) async throws -> Data {
        try await send(method, path, data: try body.map { try JSONEncoder().encode($0) }, accepted: accepted)
    }

    func send(_ method: String, _ path: String, query: [URLQueryItem] = [], data: Data? = nil, accepted: Set<Int> = [200]) async throws -> Data {
        var url = baseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(C.clientValue, forHTTPHeaderField: C.clientHeader)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let data {
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (responseData, response) = try await transport.send(request)
        guard accepted.contains(response.statusCode) else { throw Self.error(status: response.statusCode, body: responseData) }
        return responseData
    }

    func decode<Value: Decodable>(_ data: Data) throws -> Value {
        do {
            return try RemoteJSON.decoder().decode(Value.self, from: data)
        } catch {
            throw AuthError.decoding
        }
    }

    static func error(status: Int, body: Data) -> AuthError {
        let code = (try? JSONDecoder().decode(AuthErrorBody.self, from: body))?.error
        switch code {
        case "invalid_credentials": return .invalidCredentials
        case "email_taken": return .emailTaken
        case "legacy_unavailable": return .legacyUnavailable
        case "invalid_name": return .invalidName
        case "invalid_email": return .invalidEmail
        case "invalid_password": return .invalidPassword
        case "invalid_token": return .invalidToken
        case "mail_unavailable": return .mailUnavailable
        case "rate_limited": return .rateLimited
        case "invite_required": return .inviteRequired
        case "invalid_invite": return .invalidInvite
        default: break
        }
        return switch status {
        case 401: .unauthorized
        case 429: .rateLimited
        default: .server(status: status)
        }
    }
}

private struct PasswordChangeBody: Encodable {
    var current: String
    var next: String
    var endOtherSessions: Bool
}
