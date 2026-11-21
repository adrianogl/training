import Foundation

public enum RecordSource: String, Codable, Sendable, Equatable {
    case wholeRun
    case segment
}

public struct RunEffort: Codable, Sendable, Equatable {
    public let meters: Double
    public let seconds: Double
    public let source: RecordSource
    public let startMeters: Double?

    public init(meters: Double, seconds: Double, source: RecordSource, startMeters: Double? = nil) {
        self.meters = meters
        self.seconds = seconds
        self.source = source
        self.startMeters = startMeters
    }
}

public struct RunEfforts: Codable, Sendable, Equatable {
    public let activityId: Int64
    public let start: Date
    public let efforts: [RunEffort]

    public init(activityId: Int64, start: Date, efforts: [RunEffort]) {
        self.activityId = activityId
        self.start = start
        self.efforts = efforts
    }
}

public struct RecordHit: Codable, Sendable, Equatable {
    public let effort: RunEffort
    public let previousSeconds: Double?
    public let previousStart: Date?

    public init(effort: RunEffort, previousSeconds: Double?, previousStart: Date? = nil) {
        self.effort = effort
        self.previousSeconds = previousSeconds
        self.previousStart = previousStart
    }

    public var isFirst: Bool { previousSeconds == nil }
    public var gainSeconds: Double? { previousSeconds.map { $0 - effort.seconds } }
}

public struct RecordNear: Codable, Sendable, Equatable {
    public let effort: RunEffort
    public let bestSeconds: Double

    public init(effort: RunEffort, bestSeconds: Double) {
        self.effort = effort
        self.bestSeconds = bestSeconds
    }

    public var gapSeconds: Double { effort.seconds - bestSeconds }
}

public struct RunRecords: Codable, Sendable, Equatable {
    public let records: [RecordHit]
    public let near: RecordNear?

    public init(records: [RecordHit], near: RecordNear?) {
        self.records = records
        self.near = near
    }

    public static let empty = RunRecords(records: [], near: nil)

    public var improved: [RecordHit] { records.filter { !$0.isFirst } }
    public var firsts: [RecordHit] { records.filter(\.isFirst) }
}

public struct RecordStep: Codable, Sendable, Equatable {
    public let activityId: Int64
    public let start: Date
    public let seconds: Double
}

public struct RecordStanding: Codable, Sendable, Equatable {
    public let meters: Double
    public let activityId: Int64
    public let start: Date
    public let effort: RunEffort
}
