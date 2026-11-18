import Foundation

public struct AuthUser: Codable, Equatable, Sendable {
    public var email: String
    public var name: String
    public var emailVerified: Bool
    public var admin: Bool?

    public init(email: String, name: String, emailVerified: Bool, admin: Bool? = nil) {
        self.email = email
        self.name = name
        self.emailVerified = emailVerified
        self.admin = admin
    }

    public var isAdmin: Bool { admin == true }
}

public struct InvitePreview: Codable, Equatable, Sendable {
    public var name: String
    public var email: String?
    public var inviterName: String?
    public var expiresAt: Date

    public init(name: String, email: String?, inviterName: String?, expiresAt: Date) {
        self.name = name
        self.email = email
        self.inviterName = inviterName
        self.expiresAt = expiresAt
    }
}

public struct AuthSession: Codable, Equatable, Sendable {
    public var token: String
    public var user: AuthUser

    public init(token: String, user: AuthUser) {
        self.token = token
        self.user = user
    }
}

public struct AuthSessionInfo: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var device: String
    public var lastSeenAt: Date
    public var current: Bool

    public init(id: String, device: String, lastSeenAt: Date, current: Bool) {
        self.id = id
        self.device = device
        self.lastSeenAt = lastSeenAt
        self.current = current
    }
}

public enum AuthError: Error, Equatable {
    case invalidCredentials
    case emailTaken
    case legacyUnavailable
    case invalidName
    case invalidEmail
    case invalidPassword
    case invalidToken
    case mailUnavailable
    case rateLimited
    case inviteRequired
    case invalidInvite
    case unauthorized
    case server(status: Int)
    case decoding
}

struct AuthUserEnvelope: Decodable {
    var user: AuthUser
}

struct AuthSessionsEnvelope: Decodable {
    var sessions: [AuthSessionInfo]
}

struct AuthErrorBody: Decodable {
    var error: String
}
