import Foundation
import TrainingCore

extension TrainerEngineConstants {
    static let easyMaximumSeconds = 75.0 * 60
    static let longMaximumSeconds = 150.0 * 60
    static let longWeekShare = 0.30
    static let easyMinimumSeconds = 40.0 * 60
    static let easyComfortSeconds = 60.0 * 60
    static let volumeRangeCeilingMeters = 200_000.0
    static let thresholdWeekShare = 0.17
    static let vo2WeekShare = 0.08
    static let vo2MaximumWorkMeters = 10_000.0
    static let minimumQualityRepeats = 2
    static let minimumQualityBlockMeters = 1_000.0
    static let minimumTempoMeters = 2_000.0
    static let optionalMaximumSeconds = 50.0 * 60
    static let raceQualityGapDays = 4
    static let singleQualityRuns = 4
    static let qualityOffsets = [-4, -2, -3, -5, -1, 1]
    static let easyOffsets = [-2, -1, -5, -3, 1, -4]
    static let optionalOffsets = [-1, 1, -3, -5, -2, -4]
    static let qualityRankWeight = 3
    static let ruleBreakCost = 1_000
    static let strongKinds: Set<TrainerDayKind> = [.threshold, .vo2max, .long]
    static let qualityKinds: Set<TrainerDayKind> = [.threshold, .vo2max]
    static let legGroups: Set<TrainerStrengthGroup> = [.lower, .fullBody]
    static let weekendStartIndex = 5
    static let previewWeekStart = Day(year: 2000, month: 1, day: 3)
}
