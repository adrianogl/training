import Foundation
import TrainingCore

struct TrainerQualityBlock: Equatable {
    var repeats: Int
    var meters: Double
}

struct TrainerQualitySession: Equatable {
    var kind: TrainerDayKind
    var method: TrainerMethod
    var blocks: [TrainerQualityBlock]
    var closing: Bool
}

struct TrainerSkeletonContext {
    var total: Int
    var taperWeeks: Int
    var openEnded: Bool
    var longCap: Double
    var peakVolume: Double
    var lightWeeks: [Day] = []
}

struct TrainerSkeletonState {
    var volume: Double
    var long: Double
    var stage: Int
    var weeksAtStage: Int
    var started: Bool
    var returning = false
    var lastRecovery: Int?
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
    var optional: Double
    var base: Double
    var fromHistory: Bool
}

struct TrainerStrengthKind {
    var group: TrainerStrengthGroup
    var load: TrainerStrengthLoad
    var matched: Bool
}

struct TrainerGoalPaceNote {
    var pace: Double
    var previousClosed: Bool?
    var shortfall: String?
}
