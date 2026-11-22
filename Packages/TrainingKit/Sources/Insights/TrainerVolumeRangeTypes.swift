import Foundation

public struct TrainerVolumeRange: Sendable, Equatable {
    public let minimum: Double
    public let comfortable: Double
    public let limit: Double

    public init(minimum: Double, comfortable: Double, limit: Double) {
        self.minimum = minimum
        self.comfortable = comfortable
        self.limit = limit
    }

    public func fitsComfortably(_ meters: Double) -> Bool {
        meters >= minimum && meters <= comfortable
    }
}

public struct TrainerExtraDay: Sendable, Equatable {
    public let preference: TrainerDayPreference
    public let structure: [Int: TrainerDayKind]
    public let weekMeters: Double
    public let currentEasyMeters: Double
    public let currentEasySeconds: Double
    public let nextEasyMeters: Double
    public let currentLongMeters: Double
    public let nextLongMeters: Double
    public let currentWeekMeters: Double
    public let nextWeekMeters: Double
}
