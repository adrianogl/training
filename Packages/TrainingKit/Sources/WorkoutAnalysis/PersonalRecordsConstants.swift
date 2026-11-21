import Foundation

public enum PersonalRecordsConstants {
    public static let distances: [Double] = [1_000, 5_000, 10_000, 21_097.5, 42_195]
    public static let segmentDistances: [Double] = [1_000, 5_000, 10_000, 21_097.5]
    public static let wholeRunLow = 0.99
    public static let wholeRunHigh = 1.03
    public static let nearShare = 1.02
    public static let segmentMaximumGap: Double = 30
    public static let effortsVersion = 1
    static let versionScale = 10_000
}
