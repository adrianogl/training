public enum AnalysisConstants {
    public static let scoreVersion = 4
    static let completionRatio = 0.95
    static let minimumStraySeconds = 10.0
    static let sessionEndTrigger = "session_end"
    static let warmupLabel = "Aquecimento"
    static let cooldownLabel = "Desaquecimento"
    static let repeatActiveLabel = "Tiro"
    static let activeLabel = "Bloco"
    static let recoveryLabel = "Recuperação"
    static let freeRunLabel = "Volta"
    static let extraLabel = "Volta extra"
    static let kilometerLabel = "Km"
    static let kilometerSplitDistance = 1_000.0
    static let minimumPartialSplit = 100.0
    public static let pauseGapSeconds = 10.0
    public static let pauseMaximumSpeed = 0.5
    static let splitBlockMinimumDistance = 3_000.0
    static let splitBlockMinimumSeconds = 900.0

    static let fullLapMinimumDistance = 500.0
    static let minimumFullLaps = 3
    static let steadyPaceSpread = 6.0
    static let fadeThreshold = 8.0
    static let baselineKilometers = 3
    static let heartRateRiseMinimum = 3.0
    static let driftThreshold = 0.05
    static let driftMaxSpeedChange = 0.02
    static let goodRecoveryDrop = 25
    static let lowerHeartRateMargin = 3
    static let aboveExpectedMinimumComparisons = 2
    static let aboveExpectedHeartRateMargin = 3.0
    static let aboveExpectedRecoveryMargin = 5.0
    static let sameSpeedTolerance = 0.02
    static let easyBlockZoneLimit = 3
    static let hardZone = 4
    public static let lowReadiness = 50
    public static let highAcuteChronic = 1.5
    static let maxComparisons = 4
    static let metersPerKilometer = 1_000.0
}

extension AnalysisConstants {
    static let elevationNoise = 2.0
    public static let elevationMinimum = 5.0
    static let climbCost = 3.3
    static let descentGain = 1.8
    static let elevationEffectSeconds = 3.0
}

extension AnalysisConstants {
    static let executionWeight = 50.0
    static let intentWeight = 25.0
    static let costWeight = 25.0
    static let costSaturation = 0.05
    static let costMedianShare = 0.5
    static let costReasonThreshold = 0.01
    static let scoreScale = 100.0
    static let incompleteScoreCap = 95
    static let easyZoneNumber = 2
    static let raceSlowMargin = 0.10
    static let racePaceTolerance = 5.0
    static let raceFullKilometer = 950.0
}

extension AnalysisConstants {
    static let shortSleepSeconds = 6 * 3600
    static let lowSleepScore = 60
    static let lowBodyBattery = 40
    static let formMinimumSeconds = 900.0
    static let formSpeedTolerance = 0.02
    static let cadenceDrop = 3.0
    static let stanceRise = 0.04
}
