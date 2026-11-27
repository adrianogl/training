enum ThresholdEstimateConstants {
    static let maximumHeatFactor = 0.045
    static let fractionedMaximumRestSeconds = 60.0
    static let restToleranceSeconds = 5.0
    static let fractionedLastBlocks = 3
    static let blockWarmupSeconds = 60.0
    static let continuousMinimumSeconds = 15.0 * 60
    static let continuousMaximumPauseSeconds = 30.0
    static let minimumHeartRateSamples = 6
    static let sustainedSeconds = 5.0
    static let maximumSampleGapSeconds = 10.0
}
