public enum AnalysisConstants {
    public static let scoreVersion = 1
    static let completionRatio = 0.95
    static let minimumStraySeconds = 10.0
    static let sessionEndTrigger = "session_end"
    static let warmupLabel = "Aquecimento"
    static let cooldownLabel = "Desaquecimento"
    static let repeatActiveLabel = "Tiro"
    static let activeLabel = "Bloco"
    static let recoveryLabel = "Recuperação"
    static let freeRunLabel = "Volta"
    static let kilometerLabel = "Km"
    static let kilometerSplitDistance = 1_000.0
    static let minimumPartialSplit = 100.0
    static let pauseGapSeconds = 10.0
    static let pauseMaximumSpeed = 0.5
    static let splitBlockMinimumDistance = 3_000.0
    static let splitBlockMinimumSeconds = 900.0

    static let fullLapMinimumDistance = 500.0
    static let minimumFullLaps = 3
    static let steadyPaceSpread = 6.0
    static let fadeThreshold = 8.0
    static let driftThreshold = 0.05
    static let driftMaxSpeedChange = 0.02
    static let goodRecoveryDrop = 25
    static let lowerHeartRateMargin = 3
    static let sameSpeedTolerance = 0.02
    static let easyBlockZoneLimit = 3
    static let hardZone = 4
    public static let lowReadiness = 50
    public static let highAcuteChronic = 1.5
    static let maxComparisons = 4
    static let metersPerKilometer = 1_000.0
}

extension AnalysisConstants {
    static let executionWeight = 50.0
    static let intentWeight = 25.0
    static let costWeight = 25.0
    static let costSaturation = 0.05
    static let costMedianShare = 0.5
    static let costReasonThreshold = 0.01
    static let scoreScale = 100.0
    static let easyZoneNumber = 2
}
