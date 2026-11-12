public enum FITReaderConstants {
    public static let processingVersion = 3
    public static let bucketSeconds = 5.0
    static let maxRoutePoints = 500
    static let initialSimplificationTolerance = 1e-6
    static let semicircleToDegrees = 180.0 / 2_147_483_648.0
    static let physioMessageNumber: UInt16 = 140
    static let vo2maxField: UInt8 = 7
    static let recoveryMinutesField: UInt8 = 9
    static let performanceConditionField: UInt8 = 17
    static let vo2maxDivisor = 65536.0
    static let vo2maxFactor = 3.5
    static let heartRateBpmOffset = 100
    static let heartRateZones = 1...5
    static let invalidHeartRate: UInt8 = 0xFF
    static let watchZoneFloorCount = 5
}
