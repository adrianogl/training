import Foundation

public enum RemoteRecordKind: String, Codable, Sendable {
    case race
    case decision
}

public struct RemoteRecord: Codable, Equatable, Sendable {
    public var kind: RemoteRecordKind
    public var id: String
    public var updatedAt: Date
    public var deleted: Bool
    public var payload: String?
    public var seq: Int64?

    public init(kind: RemoteRecordKind, id: String, updatedAt: Date, deleted: Bool, payload: String?, seq: Int64? = nil) {
        self.kind = kind
        self.id = id
        self.updatedAt = updatedAt
        self.deleted = deleted
        self.payload = payload
        self.seq = seq
    }

    enum CodingKeys: String, CodingKey {
        case kind, id, updatedAt, deleted, payload, seq
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(id, forKey: .id)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(deleted, forKey: .deleted)
        try container.encode(payload, forKey: .payload)
        try container.encodeIfPresent(seq, forKey: .seq)
    }
}

public struct RemoteRecordKey: Codable, Hashable, Sendable {
    public var kind: RemoteRecordKind
    public var id: String

    public init(kind: RemoteRecordKind, id: String) {
        self.kind = kind
        self.id = id
    }
}

public struct RemoteChangesPage: Codable, Equatable, Sendable {
    public var records: [RemoteRecord]
    public var cursor: Int64
    public var hasMore: Bool
}

public struct RemotePushResult: Codable, Equatable, Sendable {
    public var cursor: Int64
    public var ignored: [RemoteRecordKey]
}

struct RemoteErrorBody: Decodable {
    var error: String
}

struct WatchTokenBody: Encodable {
    var tokenHash: String
}

public struct WatchReadiness: Codable, Equatable, Sendable {
    public var day: String
    public var score: Int
    public var verdict: String

    public init(day: String, score: Int, verdict: String) {
        let range = RemoteSyncConstants.watchScoreRange
        self.day = day
        self.score = min(max(score, range.lowerBound), range.upperBound)
        self.verdict = String(String.UnicodeScalarView(verdict.unicodeScalars.prefix(RemoteSyncConstants.watchVerdictMaxLength)))
    }
}

struct RemotePushBody: Encodable {
    var records: [RemoteRecord]
}

public struct RemoteDecisionPayload: Codable, Equatable, Sendable {
    public var activityId: Int64
    public var decision: String

    public init(activityId: Int64, decision: String) {
        self.activityId = activityId
        self.decision = decision
    }
}

public enum RemoteMergeAction: Equatable, Sendable {
    case insert
    case replace
    case delete
    case keepLocal
    case ignore
}

public struct RemoteSyncReport: Equatable, Sendable {
    public var pushed: Int
    public var pulled: Int
    public var applied: Int
    public var tooLarge: [RemoteRecordKey] = []
    public var quotaExceeded = false
}
