import Foundation

extension TrainerEngineConstants {
    static let cycleReadinessWeeks = 4
    static let cycleLowReadiness = 60
    static let cycleMinimumWeeks = 4
    static let cycleIncreaseShare = 0.9
    static let cycleDecreaseShare = 0.75
    static let cycleReadinessTolerance = 3.0
    static let cycleReadinessDrop = 8.0
    static let cycleIncreaseFactor = 1.08
    static let cycleDecreaseFactor = 0.9
    static let cycleWeekBelowShare = 0.8
    static let cycleMaximumReasons = 3
    static let cycleReferencePredictionMeters = 10_000.0
    static let cyclePredictionMeters: [Double] = [10_000]
}
