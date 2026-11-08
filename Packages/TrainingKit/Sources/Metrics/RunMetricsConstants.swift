enum RunMetricsConstants {
    static let vo2SmoothingDays = 14.0
    static let sampleInterval = 5.0
    static let warmupSeconds = 600.0
    static let minimumSteadySeconds = 300.0
    static let thresholdHeartRateTolerance = 3
    static let decouplingMinimumSeconds = 3600.0
    static let climbMinimumLength = 200.0
    static let climbMinimumGrade = 0.04
    static let flatMaximumGrade = 0.01
    static let flatHeartRateTolerance = 5.0
}
