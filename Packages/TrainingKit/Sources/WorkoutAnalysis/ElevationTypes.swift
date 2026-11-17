public struct ElevationCounter: Sendable {
    private var anchor: Double?

    public init() {}
    public private(set) var climb = 0.0
    public private(set) var descent = 0.0
    public private(set) var hasData = false

    public mutating func add(_ altitude: Double?) {
        guard let altitude else { return }
        hasData = true
        guard let current = anchor else {
            anchor = altitude
            return
        }
        let change = altitude - current
        guard abs(change) >= AnalysisConstants.elevationNoise else { return }
        if change > 0 { climb += change } else { descent -= change }
        anchor = altitude
    }

    public mutating func restart() {
        climb = 0
        descent = 0
    }
}
