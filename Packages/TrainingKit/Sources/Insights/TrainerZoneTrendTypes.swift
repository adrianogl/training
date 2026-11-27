import FITReader
import Foundation
import TrainingCore
import WorkoutAnalysis

public struct TrainerZoneTrendRun: Sendable, Equatable {
    public var day: Day
    public var kind: RunKind
    public var blocks: [WorkoutBlock]
    public var samples: [FITSample]

    public init(day: Day, kind: RunKind, blocks: [WorkoutBlock], samples: [FITSample] = []) {
        self.day = day
        self.kind = kind
        self.blocks = blocks
        self.samples = samples
    }
}

public struct TrainerZoneTarget: Sendable, Equatable {
    public var zone: Int
    public var paceLow: Double?
    public var paceHigh: Double?
    public var heartRateLow: Int?
    public var heartRateHigh: Int?

    public init(zone: Int, paceLow: Double?, paceHigh: Double?, heartRateLow: Int?, heartRateHigh: Int?) {
        self.zone = zone
        self.paceLow = paceLow
        self.paceHigh = paceHigh
        self.heartRateLow = heartRateLow
        self.heartRateHigh = heartRateHigh
    }
}

public struct TrainerZoneActual: Sendable, Equatable {
    public var pace: Double?
    public var heartRate: Double?

    public init(pace: Double? = nil, heartRate: Double? = nil) {
        self.pace = pace
        self.heartRate = heartRate
    }
}

public struct TrainerZoneWeek: Sendable, Equatable, Identifiable {
    public var start: Day
    public var threshold: Double
    public var targets: [TrainerZoneTarget]
    public var actual: [Int: TrainerZoneActual]

    public var id: Day { start }

    public init(start: Day, threshold: Double, targets: [TrainerZoneTarget], actual: [Int: TrainerZoneActual]) {
        self.start = start
        self.threshold = threshold
        self.targets = targets
        self.actual = actual
    }

    public func target(_ zone: Int) -> TrainerZoneTarget? { targets.first { $0.zone == zone } }
}

public enum TrainerZoneFit: Sendable, Equatable {
    case inside
    case slower(Int)
    case faster(Int)
    case above(Int)
    case below(Int)
}

public struct TrainerZoneTrend: Sendable, Equatable {
    public var weeks: [TrainerZoneWeek]
    public var goalThreshold: Double?
    public var averages: [Int: TrainerZoneActual]

    public init(weeks: [TrainerZoneWeek], goalThreshold: Double?, averages: [Int: TrainerZoneActual]) {
        self.weeks = weeks
        self.goalThreshold = goalThreshold
        self.averages = averages
    }
}

struct TrainerZoneSegment {
    var zone: Int
    var seconds: Double
    var meters: Double
    var heartRateSum: Double
    var heartRateSeconds: Double
}
