import Foundation
import TrainingCore

struct TrainerQualityStage: Equatable {
    var repeats: Int
    var meters: Double
}

struct TrainerSkeletonContext {
    var total: Int
    var taperWeeks: Int
    var openEnded: Bool
    var longCap: Double
}

struct TrainerSkeletonState {
    var volume: Double
    var long: Double
    var stage: Int
    var weeksAtStage: Int
    var started: Bool
}

struct TrainerSkeletonAdjustment {
    var holdProgression = false
    var longCap: Double?
    var volumeScale: Double?
}

struct TrainerQualityMiss: Equatable {
    var kind: TrainerDayKind
    var day: Day
    var onTarget: Int
    var total: Int
}

struct TrainerFindings {
    var longPlanned: Double?
    var longDone: Double?
    var longDay: Day?
    var longFailed = false
    var longReduced = false
    var longPaused = false
    var misses: [TrainerQualityMiss] = []
    var readiness: Double?
    var lowReadiness = false
}

struct TrainerChangeReasons {
    var strength = false
    var long: String?
    var volume: String?
    var quality: [TrainerDayKind: String] = [:]
    var requests: [ClosedRange<Day>] = []
}

struct TrainerEasyShare {
    var meters: Double
    var remaining: Double
}

struct TrainerStrengthKind {
    var group: TrainerStrengthGroup
    var load: TrainerStrengthLoad
    var matched: Bool
}
