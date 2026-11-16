import Foundation

extension TrainerEngineConstants {
    static let signalBaselineDays = 60
    static let signalMinimumWeekDays = 4
    static let signalMinimumBaselineDays = 14
    static let signalHrvDeviation = 0.5
    static let signalRestingMargin = 3.0
    static let signalSleepMargin = 2_700.0
    static let signalLoadRatio = 1.3
    static let signalLoadWindowDays = 28
    static let signalLoadMinimumDays = 8
    static let signalLoadMinimumBaselineDays = 1
    static let signalPerformanceHeartRate = 5.0
    static let signalPerformancePaceBand = 10.0
    static let signalPerformanceQualityStreak = 2
    static let signalPerformanceWeekRuns = 2
    static let signalPerformanceBaselineRuns = 3
}
