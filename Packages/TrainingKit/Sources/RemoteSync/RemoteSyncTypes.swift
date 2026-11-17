import Foundation

public enum RemoteRecordKind: String, Codable, Sendable {
    case race
    case decision
    case goal
    case trainer
    case narrative
    case preference
    case chat
}

public struct RemoteRecord: Codable, Equatable, Sendable {
    public var kind: RemoteRecordKind
    public var id: String
    public var updatedAt: Date
    public var deleted: Bool
    public var payload: String?
    public var seq: Int64?
    public var format: RemotePayloadFormat?

    public init(kind: RemoteRecordKind, id: String, updatedAt: Date, deleted: Bool, payload: String?, seq: Int64? = nil, format: RemotePayloadFormat? = nil) {
        self.kind = kind
        self.id = id
        self.updatedAt = updatedAt
        self.deleted = deleted
        self.payload = payload
        self.seq = seq
        self.format = format
    }

    enum CodingKeys: String, CodingKey {
        case kind, id, updatedAt, deleted, payload, seq, format
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(id, forKey: .id)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(deleted, forKey: .deleted)
        try container.encode(payload, forKey: .payload)
        try container.encodeIfPresent(seq, forKey: .seq)
        try container.encodeIfPresent(format, forKey: .format)
    }
}

public enum RemotePayloadFormat: String, Codable, Sendable {
    case sealed, plain
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
    public var score: Int?
    public var verdict: String?
    public var face: WatchFace?

    public init(day: String, score: Int?, verdict: String?, face: WatchFace? = nil) {
        let range = RemoteSyncConstants.watchScoreRange
        self.day = day
        if let score, let verdict {
            self.score = min(max(score, range.lowerBound), range.upperBound)
            self.verdict = String(String.UnicodeScalarView(verdict.unicodeScalars.prefix(RemoteSyncConstants.watchVerdictMaxLength)))
        }
        self.face = face
    }
}

public struct WatchEvent: Codable, Equatable, Sendable {
    public var start: Int
    public var title: String

    public init(start: Int, title: String) {
        self.start = start
        self.title = title
    }
}

public struct WatchFace: Codable, Equatable, Sendable {
    public var vo2Delta: Double?
    public var weekPlannedKm: Double?
    public var weekGoalKm: Double?
    public var workout: String?
    public var workoutShape: [[Int]]?
    public var workoutTip: String?
    public var raceName: String?
    public var raceDay: String?
    public var raceGoal: Int?
    public var racePrediction: Int?
    public var events: [WatchEvent]?

    public init(
        vo2Delta: Double? = nil,
        weekPlannedKm: Double? = nil,
        weekGoalKm: Double? = nil,
        workout: String? = nil,
        workoutShape: [[Int]]? = nil,
        workoutTip: String? = nil,
        raceName: String? = nil,
        raceDay: String? = nil,
        raceGoal: Int? = nil,
        racePrediction: Int? = nil,
        events: [WatchEvent]? = nil
    ) {
        typealias C = RemoteSyncConstants
        self.vo2Delta = vo2Delta.map { min(max($0, -C.watchFaceVO2DeltaLimit), C.watchFaceVO2DeltaLimit) }
        self.weekPlannedKm = weekPlannedKm.map { min(max($0, 0), C.watchFaceWeekKmLimit) }
        self.weekGoalKm = weekGoalKm.flatMap { $0 > 0 ? min($0, C.watchFaceWeekKmLimit) : nil }
        self.workout = workout.flatMap(Self.text)
        self.workoutShape = workoutShape.flatMap { shape in
            let steps = shape.prefix(C.watchFaceShapeMaxSteps).map { step in
                [
                    min(max(step.first ?? 1, 1), C.watchFaceShapeMaxWeight),
                    min(max(step.last ?? C.watchFaceZoneRange.lowerBound, C.watchFaceZoneRange.lowerBound), C.watchFaceZoneRange.upperBound),
                ]
            }
            return steps.isEmpty ? nil : Array(steps)
        }
        self.workoutTip = workoutTip.flatMap(Self.text)
        self.raceName = raceName.flatMap(Self.text)
        self.raceDay = raceDay
        self.raceGoal = raceGoal.flatMap { (1...C.watchFaceRaceSecondsLimit).contains($0) ? $0 : nil }
        self.racePrediction = racePrediction.flatMap { (1...C.watchFaceRaceSecondsLimit).contains($0) ? $0 : nil }
        let validEvents = (events ?? []).compactMap { event -> WatchEvent? in
            guard (1...C.watchFaceEventStartLimit).contains(event.start), let title = Self.text(event.title) else { return nil }
            return WatchEvent(start: event.start, title: title)
        }
        self.events = events == nil ? nil : Array(validEvents.prefix(C.watchFaceMaxEvents))
    }

    private static func text(_ value: String) -> String? {
        let trimmed = String(String.UnicodeScalarView(value.unicodeScalars.prefix(RemoteSyncConstants.watchFaceTextMaxLength)))
        return trimmed.isEmpty ? nil : trimmed
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
    public var trainerChanged = false
    public var narrativesChanged = false
    public var changedKinds: Set<RemoteRecordKind> = []
}

public struct RemoteTrainerState: Equatable, Sendable {
    public var data: Data?
    public var updatedAt: Date

    public init(data: Data?, updatedAt: Date) {
        self.data = data
        self.updatedAt = updatedAt
    }

    public var deleted: Bool { data == nil }
}

public protocol RemoteTrainerStore: Sendable {
    func pending() -> RemoteTrainerState?
    func updatedAt() -> Date?
    func markPending()
    func markPushed(updatedAt: Date)
    func apply(_ remote: RemoteTrainerState) -> Bool
}

public struct RemoteNarrative: Equatable, Sendable {
    public var id: String
    public var text: String
    public var updatedAt: Date

    public init(id: String, text: String, updatedAt: Date) {
        self.id = id
        self.text = text
        self.updatedAt = updatedAt
    }
}

public protocol RemoteNarrativeStore: Sendable {
    func pendingNarratives() -> [RemoteNarrative]
    func narrativeUpdatedAt(id: String) -> Date?
    func markNarrativesPushed(_ narratives: [RemoteNarrative])
    func apply(_ narrative: RemoteNarrative) -> Bool
}

public struct RemoteBlob: Equatable, Sendable {
    public var id: String
    public var data: Data
    public var updatedAt: Date

    public init(id: String, data: Data, updatedAt: Date) {
        self.id = id
        self.data = data
        self.updatedAt = updatedAt
    }
}

public protocol RemoteBlobStore: Sendable {
    var kind: RemoteRecordKind { get }
    func pendingBlobs() -> [RemoteBlob]
    func markBlobsPushed(_ blobs: [RemoteBlob])
    func apply(_ blob: RemoteBlob) -> Bool
    func handles(_ id: String) -> Bool
}

public extension RemoteBlobStore {
    func handles(_ id: String) -> Bool { true }
}
