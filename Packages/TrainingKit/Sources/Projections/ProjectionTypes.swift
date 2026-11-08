import TrainingCore

public struct ProjectionPoint: Sendable, Equatable {
    public var day: Day
    public var mid: Double
    public var low: Double
    public var high: Double

    public init(day: Day, mid: Double, low: Double, high: Double) {
        self.day = day
        self.mid = mid
        self.low = low
        self.high = high
    }
}

public struct Projection: Sendable {
    public var points: [ProjectionPoint]
    public var targetCrossing: Day?

    public init(points: [ProjectionPoint], targetCrossing: Day?) {
        self.points = points
        self.targetCrossing = targetCrossing
    }
}
