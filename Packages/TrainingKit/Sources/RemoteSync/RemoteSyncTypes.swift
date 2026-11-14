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
    public var face: WatchFace?

    public init(day: String, score: Int, verdict: String, face: WatchFace? = nil) {
        let range = RemoteSyncConstants.watchScoreRange
        self.day = day
        self.score = min(max(score, range.lowerBound), range.upperBound)
        self.verdict = String(String.UnicodeScalarView(verdict.unicodeScalars.prefix(RemoteSyncConstants.watchVerdictMaxLength)))
        self.face = face
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
        racePrediction: Int? = nil
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
}
