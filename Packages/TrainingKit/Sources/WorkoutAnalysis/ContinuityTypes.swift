public struct RunPause: Sendable, Equatable {
    public var startMeters: Double
    public var seconds: Double

    public init(startMeters: Double, seconds: Double) {
        self.startMeters = startMeters
        self.seconds = seconds
    }
}

public struct RunContinuity: Sendable, Equatable {
    public var totalMeters: Double
    public var movingSeconds: Double
    public var pauses: [RunPause]
    public var longestContinuousMeters: Double

    public init(totalMeters: Double, movingSeconds: Double, pauses: [RunPause], longestContinuousMeters: Double) {
        self.totalMeters = totalMeters
        self.movingSeconds = movingSeconds
        self.pauses = pauses
        self.longestContinuousMeters = longestContinuousMeters
    }

    public var paceSecondsPerKm: Double? {
        totalMeters > 0 && movingSeconds > 0 ? movingSeconds / (totalMeters / 1_000) : nil
    }

    public func meetsContinuousGoal(distanceKm: Double, paceSecondsPerKm target: Double) -> Bool {
        guard pauses.isEmpty, totalMeters >= distanceKm * 1_000, let pace = paceSecondsPerKm else { return false }
        return pace <= target
    }
}
