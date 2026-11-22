import Foundation
import TrainingCore

public enum TrainerExcludedWeekReason: Sendable, Equatable {
    case light, taper, race, low
}

public struct TrainerExcludedWeek: Sendable, Equatable {
    public let start: Day
    public let reason: TrainerExcludedWeekReason

    public init(start: Day, reason: TrainerExcludedWeekReason) {
        self.start = start
        self.reason = reason
    }
}

public struct TrainerNormalVolume: Sendable, Equatable {
    public let meters: Double
    public let excluded: [TrainerExcludedWeek]
    public let fromNormalWeeks: Bool

    public init(meters: Double, excluded: [TrainerExcludedWeek], fromNormalWeeks: Bool) {
        self.meters = meters
        self.excluded = excluded
        self.fromNormalWeeks = fromNormalWeeks
    }
}

public enum TrainerVolumeLimit: Sendable, Equatable {
    case cycle(TrainerCycleVerdict)
    case growth
    case comfortable(runs: Int)
    case deadline(weeks: Int)
}

public struct TrainerVolumeSuggestion: Sendable, Equatable {
    public let startMeters: Double
    public let peakMeters: Double
    public let limit: TrainerVolumeLimit
    public let base: TrainerNormalVolume

    public init(startMeters: Double, peakMeters: Double, limit: TrainerVolumeLimit, base: TrainerNormalVolume) {
        self.startMeters = startMeters
        self.peakMeters = peakMeters
        self.limit = limit
        self.base = base
    }
}
