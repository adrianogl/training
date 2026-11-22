import Foundation

public struct UsualHourRun: Sendable, Equatable, Codable {
    public let start: Date
    public let meters: Double
    public let seconds: Double

    public init(start: Date, meters: Double, seconds: Double) {
        self.start = start
        self.meters = meters
        self.seconds = seconds
    }

    public var isLong: Bool {
        meters >= UsualHourConstants.longMeters || seconds >= UsualHourConstants.longSeconds
    }
}

public enum UsualHourSource: Sendable, Equatable {
    case longRuns, weekend, weekday, allRuns, fallback
}
