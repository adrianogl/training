import Foundation

enum HealthImportConstants {
    static let sampleStep = 5.0
    static let speedWindow = 10.0
    static let fallbackMaxHeartRate = 190.0
    static let fallbackRestingHeartRate = 60.0
    static let restingWindowDays = 30
    static let hrvBaselineDays = 60
    static let hrvMinimumNights = 14
    static let hrvLowSD = 1.5
    static let hrvBalancedLowSD = 0.5
    static let hrvBalancedHighSD = 1.0
    static let hrvWeekDays = 7
    static let trimpFactor = 0.64
    static let trimpExponent = 1.92
    static let sleepTargetSeconds = 8.0 * 3600
    static let sleepDurationPoints = 70.0
    static let sleepStagePoints = 30.0
    static let sleepStageTarget = 0.4
    static let zoneFloors = [0.5, 0.6, 0.7, 0.8, 0.9]
    static let historyYears = 2
    static let activityIdMask: UInt64 = 0x0FFF_FFFF_FFFF_FFFF
    static let activityIdMarker: UInt64 = 0x1000_0000_0000_0000
    static let fnvOffset: UInt64 = 14_695_981_039_346_656_037
    static let fnvPrime: UInt64 = 1_099_511_628_211
    static let millisecondsPerSecond = 1000.0
    static let defaultZonesSport = "DEFAULT"
}
