import Foundation

public struct GarminAccountSession: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    public var clientId: String
    public var expiresAt: Date

    public init(accessToken: String, refreshToken: String?, clientId: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.clientId = clientId
        self.expiresAt = expiresAt
    }
}

public struct GarminMFAChallenge: Sendable, Equatable {
    public let method: String

    public init(method: String) {
        self.method = method
    }
}

public enum GarminLoginResult: Sendable, Equatable {
    case signedIn(GarminAccountSession)
    case needsCode(GarminMFAChallenge)
}

public enum GarminAccountError: Error, Equatable, Sendable {
    case invalidCredentials
    case invalidCode
    case rateLimited
    case unexpectedResponse(status: Int)
    case exchangeFailed
    case sessionExpired
}

struct GarminSSOResponse: Decodable {
    struct Status: Decodable {
        let type: String?
    }

    struct MFAInfo: Decodable {
        let mfaLastMethodUsed: String?
    }

    let responseStatus: Status?
    let serviceTicketId: String?
    let customerMfaInfo: MFAInfo?
}

struct GarminTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
}
