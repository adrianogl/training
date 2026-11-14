import Foundation

public enum GarminLinkOutcome: Equatable, Sendable {
    case connected
    case needsCode(method: String)
}

public enum GarminLinkError: Error, Equatable {
    case invalidCredentials
    case invalidCode
    case loginExpired
    case rateLimited
    case notConnected
    case unavailable
    case unauthorized
    case server(status: Int)
}

struct GarminLinkStatusBody: Decodable {
    var status: String
    var method: String?
}

struct GarminLinkStateBody: Decodable {
    var connected: Bool
}

struct GarminLinkSessionBody: Decodable {
    var accessToken: String
    var refreshToken: String?
    var clientId: String
    var expiresAt: Date
}
