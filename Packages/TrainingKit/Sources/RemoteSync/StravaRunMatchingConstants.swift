import Foundation

public enum StravaRunMatchingConstants {
    public static let window: TimeInterval = 15 * 60
    public static let distanceTolerance = 0.1
    public static let backfillDays = 365
    public static let recentDays = 28
    static let retryLater = "retry_later"
}
