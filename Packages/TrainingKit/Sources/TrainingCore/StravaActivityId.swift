import Foundation

public enum StravaActivityId {
    public static let lowerBound = Int64(bitPattern: StravaActivityIdConstants.marker)
    public static let upperBound = Int64(bitPattern: StravaActivityIdConstants.marker | StravaActivityIdConstants.mask)

    public static func make(_ stravaId: Int64) -> Int64 {
        Int64(bitPattern: (UInt64(bitPattern: stravaId) & StravaActivityIdConstants.mask) | StravaActivityIdConstants.marker)
    }

    public static func isStrava(_ activityId: Int64) -> Bool {
        UInt64(bitPattern: activityId) & ~StravaActivityIdConstants.mask == StravaActivityIdConstants.marker
    }

    public static func stravaId(_ activityId: Int64) -> Int64? {
        isStrava(activityId) ? Int64(bitPattern: UInt64(bitPattern: activityId) & StravaActivityIdConstants.mask) : nil
    }
}
