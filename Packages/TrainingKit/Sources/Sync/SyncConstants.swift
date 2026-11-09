import Foundation

enum SyncConstants {
    static let dailySummaryWindowDays = 180
    static let hrvWindowDays = 180
    static let sleepWindowDays = 28
    static let bodyBatteryWindowDays = 28
    static let activityPageSize = 50
    static let incrementalOverlapDays = 3
    static let incrementalActivityOverlap: TimeInterval = 3 * 86_400
    static let chronicLoadDays = 28
    static let readinessVersion = 1
    static let defaultZonesSport = "DEFAULT"
    static let missingFITStatuses: Set<Int> = [404, 410]

    static let progressAfterCleanup = 0.05
    static let progressAfterZones = 0.1
    static let progressAfterDaily = 0.5
    static let progressAfterActivities = 0.7
    static let progressAfterFIT = 0.9
    static let progressAfterDerived = 0.95
}
