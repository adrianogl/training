import Foundation
import GarminAPI

public struct AdminClient: Sendable {
    private typealias C = AdminConstants
    private let client: AuthClient

    public init(baseURL: URL, token: String, transport: any HTTPTransport) {
        client = AuthClient(baseURL: baseURL, token: token, transport: transport)
    }

    public func snapshot() async throws -> AdminSnapshot {
        try client.decode(try await client.send("GET", C.overviewPath))
    }

    public func createInvite(name: String, channel: InviteChannel, email: String?) async throws -> InviteDelivery {
        let body = AdminInviteBody(name: name, channel: channel, email: channel == .email ? email : nil)
        return try client.decode(try await client.send("POST", C.invitesPath, data: try JSONEncoder().encode(body)))
    }

    public func renewInvite(id: String) async throws -> InviteDelivery {
        try client.decode(try await action(C.inviteActionPath, id: id, action: C.renewAction))
    }

    public func cancelInvite(id: String) async throws {
        _ = try await action(C.inviteActionPath, id: id, action: C.cancelAction)
    }

    public func inviteFromRequest(id: String) async throws -> InviteDelivery {
        try client.decode(try await action(C.requestActionPath, id: id, action: C.inviteAction))
    }

    public func declineRequest(id: String) async throws {
        _ = try await action(C.requestActionPath, id: id, action: C.declineAction)
    }

    public func deleteUser(id: String) async throws {
        _ = try await client.send("DELETE", C.usersPath, query: [URLQueryItem(name: C.userIdQuery, value: id)], accepted: [204])
    }

    private func action(_ path: String, id: String, action: String) async throws -> Data {
        try await client.send("POST", path, data: try JSONEncoder().encode(AdminActionBody(id: id, action: action)))
    }
}
