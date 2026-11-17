import Foundation

public struct PaceBand: Sendable, Equatable {
    public var fastest: Double
    public var slowest: Double

    public init(fastest: Double, slowest: Double) {
        self.fastest = min(fastest, slowest)
        self.slowest = max(fastest, slowest)
    }
}

public struct RunTimeRange: Sendable, Equatable {
    public var fastest: Double
    public var slowest: Double
    public var approximate: Bool

    public init(fastest: Double, slowest: Double, approximate: Bool = false) {
        self.fastest = fastest
        self.slowest = slowest
        self.approximate = approximate
    }
}

public enum RunTimePart: Sendable, Equatable {
    case fixed(seconds: Double)
    case distance(meters: Double, pace: PaceBand?)
    case open
}
