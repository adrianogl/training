public struct FITSummary: Sendable {
    public var samples: [FITSample]
    public var route: [Coordinate]
    public var physio: PhysioMetrics?
    public var structure: WorkoutStructure

    public init(samples: [FITSample], route: [Coordinate], physio: PhysioMetrics?, structure: WorkoutStructure = WorkoutStructure()) {
        self.samples = samples
        self.route = route
        self.physio = physio
        self.structure = structure
    }
}
