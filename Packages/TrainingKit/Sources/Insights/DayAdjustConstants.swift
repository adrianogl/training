import Foundation

public enum DayAdjustConstants {
    public static let readinessSteps: [(minimum: Int, seconds: Int)] = [(70, 0), (60, 3), (50, 6)]
    public static let restBelow = 50
    public static let heavyLegsSeconds = 3
    public static let maximumSeconds = 15
    public static let shortenShare = 0.8
    public static let defaultHour = 7
    public static let usualWindowDays = 30
    static let roundingMeters = 100.0
}
