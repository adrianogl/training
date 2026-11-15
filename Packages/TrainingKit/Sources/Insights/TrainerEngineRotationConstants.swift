import Foundation

extension TrainerEngineConstants {
    static let blockLength = 3
    static let longestWeekShare = 0.35
    static let longestGrowth = 1.2
    static let longestOverRaceCap = 1.1
    static let stimulusShare = 0.85
    static let longFloorWeekMeters = 60_000.0
    static let longFloorMeters = 18_000.0
    static let longCeilingMeters = 24_000.0
    static let progressiveLongShare = 0.2
    static let progressiveLongMinimumMeters = 3_000.0
    static let progressiveLongMaximumMeters = 5_000.0
    static let progressiveLongOffset = 15.0
    static let fastFinishMeters = 2_000.0
    static let fastFinishOffset = 10.0
    static let racePaceLongRepeats = 3
    static let racePaceLongPhases: Set<TrainerPhase> = [.build, .specific]
    static let racePaceLongMeters = 3_000.0
    static let racePaceLongShortMeters = 2_000.0
    static let racePaceLongShortBelow = 16_000.0
    static let racePaceLongJogMeters = 1_000.0
    static let continuousTempoMeters: [TrainerPhase: Double] = [.general: 6_000, .base: 6_000, .build: 7_000, .specific: 8_000]
    static let progressiveThresholdRepeats = 3
    static let progressiveThresholdMeters = 2_000.0
    static let progressiveThresholdStep = 5.0
    static let vo2Rotation: [TrainerVo2Format] = [.oneKm, .eightHundred, .longReps, .shortReps, .pyramid]
    static let hillRepeats = 8
    static let hillRecoveryRepeats = 6
    static let hillMeters = 200.0
    static let eightHundredRepeats = 6
    static let eightHundredRecoveryRepeats = 4
    static let eightHundredMeters = 800.0
    static let shortRecoveryRepeats = 8
    static let longRecoveryRepeats = 2
    static let stridesRepeats = 6
    static let stridesMeters = 100.0
    static let stridesRestSeconds = 60.0
    static let mediumLongWeekMeters = 65_000.0
    static let mediumLongShare = 0.2
    static let mediumLongMinimumMeters = 14_000.0
    static let mediumLongMaximumMeters = 16_000.0
    static let fartlekRepeats = 6
    static let fartlekMeters = 500.0
    static let fartlekEvery = 2
}
