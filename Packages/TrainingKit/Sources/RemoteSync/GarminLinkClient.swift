import Foundation
import GarminAPI

public struct GarminLinkClient: Sendable {
    private let baseURL: URL
    private let token: String
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: String, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    public func connect(email: String, password: String) async throws -> GarminLinkOutcome {
        try outcome(try await send("POST", "api/v1/garmin/connect", body: ["email": email, "password": password]))
    }

    public func verify(code: String) async throws -> GarminLinkOutcome {
        try outcome(try await send("POST", "api/v1/garmin/verify", body: ["code": code]))
    }

    public func isConnected() async throws -> Bool {
        try RemoteJSON.decoder().decode(GarminLinkStateBody.self, from: try await send("GET", "api/v1/garmin/status")).connected
    }

    public func disconnect() async throws {
        _ = try await send("DELETE", "api/v1/garmin/status", accepted: [204])
    }

    public func session() async throws -> GarminAccountSession {
        let body = try RemoteJSON.decoder().decode(GarminLinkSessionBody.self, from: try await send("GET", "api/v1/garmin/session"))
        return GarminAccountSession(accessToken: body.accessToken, refreshToken: body.refreshToken, clientId: body.clientId, expiresAt: body.expiresAt)
    }

    private func outcome(_ data: Data) throws -> GarminLinkOutcome {
        let body = try JSONDecoder().decode(GarminLinkStatusBody.self, from: data)
        return body.status == "needs_code" ? .needsCode(method: body.method ?? "email") : .connected
    }

    private func send(_ method: String, _ path: String, body: [String: String]? = nil, accepted: Set<Int> = [200]) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport.send(request)
        guard accepted.contains(response.statusCode) else { throw Self.error(status: response.statusCode, body: data) }
        return data
    }

    static func error(status: Int, body: Data) -> GarminLinkError {
        switch (try? JSONDecoder().decode(AuthErrorBody.self, from: body))?.error {
        case "garmin_invalid_credentials": return .invalidCredentials
        case "garmin_invalid_code": return .invalidCode
        case "garmin_login_expired": return .loginExpired
        case "garmin_rate_limited": return .rateLimited
        case "garmin_not_connected": return .notConnected
        case "garmin_unavailable", "storage_unavailable": return .unavailable
        default: return status == 401 ? .unauthorized : .server(status: status)
        }
    }
}
