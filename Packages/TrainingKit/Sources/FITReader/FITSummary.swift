public struct FITSummary: Sendable {
    public var samples: [FITSample]
    public var route: [Coordinate]
    public var physio: PhysioMetrics?

    public init(samples: [FITSample], route: [Coordinate], physio: PhysioMetrics?) {
        self.samples = samples
        self.route = route
        self.physio = physio
    }
}
