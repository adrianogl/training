import Foundation

public enum InviteChannel: String, Codable, CaseIterable, Sendable {
    case email, whatsapp, link
}

public enum InviteStatus: String, Codable, Sendable {
    case pending, accepted, expired, canceled
}

public struct AdminCounts: Codable, Equatable, Sendable {
    public var accounts: Int
    public var maxAccounts: Int
    public var pendingInvites: Int

    public init(accounts: Int, maxAccounts: Int, pendingInvites: Int) {
        self.accounts = accounts
        self.maxAccounts = maxAccounts
        self.pendingInvites = pendingInvites
    }
}

public struct AdminUser: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var email: String
    public var admin: Bool
    public var garminConnected: Bool
    public var lastSeenAt: Date?
    public var dataBytes: Int

    public init(id: String, name: String, email: String, admin: Bool, garminConnected: Bool, lastSeenAt: Date?, dataBytes: Int) {
        self.id = id
        self.name = name
        self.email = email
        self.admin = admin
        self.garminConnected = garminConnected
        self.lastSeenAt = lastSeenAt
        self.dataBytes = dataBytes
    }
}

public struct AdminInvite: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var email: String?
    public var channel: InviteChannel
    public var status: InviteStatus
    public var createdAt: Date
    public var expiresAt: Date
    public var acceptedAt: Date?

    public init(id: String, name: String, email: String?, channel: InviteChannel, status: InviteStatus, createdAt: Date, expiresAt: Date, acceptedAt: Date?) {
        self.id = id
        self.name = name
        self.email = email
        self.channel = channel
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.acceptedAt = acceptedAt
    }
}

public struct AdminInviteRequest: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var email: String
    public var watch: String
    public var message: String
    public var createdAt: Date

    public init(id: String, name: String, email: String, watch: String, message: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.email = email
        self.watch = watch
        self.message = message
        self.createdAt = createdAt
    }
}

public struct AdminSnapshot: Codable, Equatable, Sendable {
    public var overview: AdminCounts
    public var users: [AdminUser]
    public var invites: [AdminInvite]
    public var requests: [AdminInviteRequest]

    public init(overview: AdminCounts, users: [AdminUser], invites: [AdminInvite], requests: [AdminInviteRequest]) {
        self.overview = overview
        self.users = users
        self.invites = invites
        self.requests = requests
    }
}

public struct InviteDelivery: Codable, Equatable, Sendable {
    public var invite: AdminInvite
    public var link: String
    public var message: String
    public var mailed: Bool

    public init(invite: AdminInvite, link: String, message: String, mailed: Bool) {
        self.invite = invite
        self.link = link
        self.message = message
        self.mailed = mailed
    }
}

struct AdminInviteBody: Encodable {
    var name: String
    var channel: InviteChannel
    var email: String?
}

struct AdminActionBody: Encodable {
    var id: String
    var action: String
}
