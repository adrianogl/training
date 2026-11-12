public struct FITSummary: Sendable {
    public var samples: [FITSample]
    public var route: [Coordinate]
    public var physio: PhysioMetrics?
    public var structure: WorkoutStructure
    public var zoneInfo: HeartRateZoneInfo?

    public init(
        samples: [FITSample],
        route: [Coordinate],
        physio: PhysioMetrics?,
        structure: WorkoutStructure = WorkoutStructure(),
        zoneInfo: HeartRateZoneInfo? = nil
    ) {
        self.samples = samples
        self.route = route
        self.physio = physio
        self.structure = structure
        self.zoneInfo = zoneInfo
    }
}
