enum RaceDetectionConstants {
    static let distanceTolerance = 0.04
    static let nominalDistances: [Double] = [5_000, 10_000, 21_097.5, 42_195]
    static let fasterThanBaseline = 0.06
    static let baselineDistanceTolerance = 0.20
    static let baselineDays = 180
    static let thresholdFraction = 0.95
    static let lookbackDays = 365
}
