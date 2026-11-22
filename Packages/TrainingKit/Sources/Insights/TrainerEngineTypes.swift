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
    var variant: TrainerVariant? = nil
    var turnAfterRep: Int? = nil
    var tailMeters = 0.0
    var warmupExtraMeters = 0.0
}

struct TrainerSkeletonContext {
    var total: Int
    var taperWeeks: Int
    var openEnded: Bool
    var longCap: Double
    var longCapByVolume: ((Double) -> Double)? = nil
    var peakVolume: Double
    var lightWeeks: [Day] = []
    var earlyLightWeeks: [Day: TrainerLightKind] = [:]
    var calmWeeks: [Day] = []
    var generalWeeks = 0
    var outAndBack = false

    func longCap(at volume: Double) -> Double {
        longCapByVolume.map { max(longCap, $0(volume)) } ?? longCap
    }
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
    var signals: [TrainerSignal] = []
}

enum TrainerSignalDecision: Equatable {
    case early(TrainerLightKind)
    case calm
}

struct TrainerChangeReasons {
    var override: String?
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
    var first: Double? = nil
    var firstDay: Int? = nil
    var mediumLong: Double? = nil
    var mediumLongDay: Int? = nil
    var fartlek = false
}

enum TrainerVo2Format: Equatable {
    case hills
    case oneKm
    case eightHundred
    case longReps
    case shortReps
    case pyramid
}

enum TrainerThresholdFormat: Equatable {
    case ladder
    case continuous
    case progressive
}

enum TrainerLongStimulus: Equatable {
    case progressive
    case fastFinish
    case racePace
}

enum TrainerLongRole: Equatable {
    case plain
    case longest
    case stimulus(TrainerLongStimulus)
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

struct TrainerLongEvidence: Equatable {
    var count: Int
    var km: Int
}

struct TrainerLongPlan: Equatable {
    var mode: TrainerLongMode = .continuous
    var evidence: TrainerLongEvidence?
    var stage = 1
    var streak = 0
    var misses = 0
}

struct TrainerLongOutcome {
    var long: TrainerLongPlan
    var sentences: [String] = []
    var changes: [TrainerChange] = []
}
