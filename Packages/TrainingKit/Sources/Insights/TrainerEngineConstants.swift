import Foundation

enum TrainerEngineConstants {
    static let defaultStructure: [Int: TrainerDayKind] = [
        1: .easy, 2: .threshold, 3: .easy, 4: .vo2max, 5: .optionalEasy, 6: .long, 7: .off,
    ]
    static let metersPerKilometer = 1_000.0
    static let daysPerWeek = 7
    static let paceWindowDays = 90
    static let workPaceRuns = 4
    static let volumeWindowDays = 28
    static let volumeWindowWeeks = 4.0
    static let longWindowDays = 30
    static let detailDays = 15
    static let qualityBand = 3.0
    static let easyBand = 7.0
    static let longBelowEasy = 5.0
    static let thresholdAbovePrediction = 8.0
    static let vo2BelowThreshold = 15.0
    static let thresholdBelowEasy = 60.0
    static let fallbackEasyPace = 360.0
    static let thresholdPredictionMeters = 10_000.0
    static let vo2PredictionMeters = 5_000.0
    static let fallbackWeeklyMeters = 15_000.0
    static let minimumLongMeters = 10_000.0
    static let fallbackLongCap = 20_000.0
    static let longCaps: [(upTo: Double, cap: Double)] = [
        (7_500, 14_000), (15_000, 16_000), (30_000, 22_000), (.infinity, 32_000),
    ]
    static let weeklyGrowth = 0.03
    static let peakVolumeShare = 1.10
    static let longStep = 2_000.0
    static let recoveryEvery = 4
    static let recoveryVolumeShare = 0.8
    static let recoveryLongShare = 0.75
    static let taperShares = [0.7, 0.5]
    static let baseShare = 0.30
    static let buildShare = 0.35
    static let taperWeeks = 2
    static let shortRaceTaperWeeks = 1
    static let shortRaceMeters = 10_000.0
    static let openHorizonWeeks = 12
    static let openPhaseWeeks = 4
    static let warmupMeters = 3_000.0
    static let slowStartMeters = 5_000.0
    static let slowStartSeconds = 10.0
    static let strengthWindowDays = 28
    static let strengthMinimumDays = 2
    static let lowerWords = ["mmii", "inferior", "perna", "leg"]
    static let upperWords = ["superior", "upper", "braco", "peito", "costas"]
    static let fullBodyWords = ["full"]
    static let coreWords = ["core", "abdom"]
    static let thresholdRestShare = 0.2
    static let vo2RestShare = 0.9
    static let thresholdMinimumRestSeconds = 60.0
    static let vo2MinimumRestSeconds = 120.0
    static let restStepSeconds = 30.0
    static let extraRestSeconds = 60.0
    static let thresholdStages = [
        TrainerQualityStage(repeats: 3, meters: 2_000), TrainerQualityStage(repeats: 4, meters: 2_000),
        TrainerQualityStage(repeats: 3, meters: 3_000), TrainerQualityStage(repeats: 4, meters: 3_000),
    ]
    static let vo2Stages = [
        TrainerQualityStage(repeats: 5, meters: 1_000), TrainerQualityStage(repeats: 6, meters: 1_000),
        TrainerQualityStage(repeats: 5, meters: 1_200), TrainerQualityStage(repeats: 6, meters: 1_200),
    ]
    static let stagesAtLevel = 2
    static let minimumEasyMeters = 6_000.0
    static let maximumEasyMeters = 14_000.0
    static let fallbackEasyMeters = 8_000.0
    static let easyWindowDays = 42
    static let halfKilometer = 500.0
    static let optionalEasyShare = 0.7
    static let optionalMinimumMeters = 5_000.0
    static let optionalReadiness = 60
    static let raceWeekEasyMeters = 5_000.0
    static let doneShare = 0.9
    static let longFailShare = 0.85
    static let longReduceShare = 0.7
    static let longReduceMeters = 2_000.0
    static let readinessTrigger = 50
    static let readinessWeek = 55.0
    static let readinessScale = 0.9
    static let painScale = 0.7
    static let painMinimumMeters = 3_000.0
    static let painQualityMeters = 6_000.0
    static let travelRunMeters = 6_000.0
    static let moreTimeMeters = 6_000.0
    static let travelPeriodDays = 1
    static let painPeriodDays = 7
    static let moreTimePeriodDays = 15
    static let returnSearchDays = 3
    static let gelBeforeFadeKm = 2
    static let paceChangeSeconds = 2.0
    static let travelWords = Words(exact: ["viagem", "viagens", "hotel"], prefixes: ["viaj"], phrases: [])
    static let painWords = Words(exact: ["dor", "dores"], prefixes: ["lesa", "incomod", "machuc"], phrases: [])
    static let fatigueWords = Words(exact: [], prefixes: ["cansad", "cansac", "exaust", "sono"], phrases: [])
    static let moreTimeWords = Words(exact: ["folga", "livre"], prefixes: [], phrases: ["mais tempo"])
    static let goalWords = Words(exact: ["meta", "metas"], prefixes: [], phrases: ["prova nova"])

    struct Words {
        var exact: [String]
        var prefixes: [String]
        var phrases: [String]
    }
}
