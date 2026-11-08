import Foundation

public enum GarminEndpoints {
    public static let base = URL(string: "https://personal.connectapi.garmin.com")!
    public static let tokenPath = "/personalapitoken-service/personal-api/personal-api-key/token"

    public static let heartRateZonesPath = "/biometric-service/heartRateZones/v2"
    public static let dailySummariesPath = "/usersummary-service/v2/dailysummaries"
    public static let hrvPathPrefix = "/hrv-service/hrv/daily"
    public static let sleepPath = "/sleep-service/sleep/dailySleepSummariesByDate"
    public static let bodyBatteryPath = "/wellness-service/wellness/bodyBattery/reports/daily"
    public static let activitiesPath = "/activitylist-service/activities/search/activities"
    public static let fitDownloadPathPrefix = "/download-service/files/activity"

    public static let retryDelaysSeconds = [1, 2, 4]

    public static let hrvMaxDays = 180
    public static let dailySummariesMaxDays = 180
    public static let sleepMaxDays = 28
    public static let bodyBatteryMaxDays = 28
    public static let stressMaxDays = 7
    public static let stepsMaxDays = 7
    public static let activitiesPageSize = 50
}
