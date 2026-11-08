import Foundation

public enum GarminEndpoints {
    public static let base = URL(string: "https://personal.connectapi.garmin.com")!
    public static let tokenPath = "/personalapitoken-service/personal-api/personal-api-key/token"

    public static let hrvMaxDays = 180
    public static let dailySummariesMaxDays = 180
    public static let sleepMaxDays = 28
    public static let bodyBatteryMaxDays = 28
    public static let stressMaxDays = 7
    public static let stepsMaxDays = 7
    public static let activitiesPageSize = 50
}
