import Foundation
import TrainingCore

extension TrainerEngineConstants {
    static let easyMaximumSeconds = 75.0 * 60
    static let longMaximumSeconds = 150.0 * 60
    static let longWeekShare = 0.30
    static let optionalMaximumMeters = 8_000.0
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
    static let previewWeekStart = Day(year: 2000, month: 1, day: 3)
}
