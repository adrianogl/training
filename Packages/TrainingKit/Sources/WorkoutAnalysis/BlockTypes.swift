import FITReader

public struct HeartRateZones: Sendable, Equatable {
    public var floors: [Int]
    public var maxHeartRate: Int?

    public init(floors: [Int], maxHeartRate: Int? = nil) {
        self.floors = floors
        self.maxHeartRate = maxHeartRate
    }
}

public enum BlockKind: String, Codable, Sendable {
    case warmup, active, recovery, cooldown
}

public enum BlockStatus: String, Codable, Sendable {
    case inTarget, faster, slower, aboveTarget, belowTarget, noTarget, incomplete, notExecuted
}

public struct WorkoutBlock: Codable, Sendable, Equatable {
    public var kind: BlockKind
    public var ordinal: Int
    public var label: String
    public var prescribed: PrescribedStep?
    public var laps: [LapSummary]
    public var seconds: Double
    public var distance: Double
    public var avgSpeed: Double?
    public var avgHeartRate: Int?
    public var maxHeartRate: Int?
    public var dominantZone: Int?
    public var status: BlockStatus

    public init(
        kind: BlockKind,
        ordinal: Int,
        label: String,
        prescribed: PrescribedStep?,
        laps: [LapSummary],
        seconds: Double,
        distance: Double,
        avgSpeed: Double?,
        avgHeartRate: Int?,
        maxHeartRate: Int?,
        dominantZone: Int?,
        status: BlockStatus
    ) {
        self.kind = kind
        self.ordinal = ordinal
        self.label = label
        self.prescribed = prescribed
        self.laps = laps
        self.seconds = seconds
        self.distance = distance
        self.avgSpeed = avgSpeed
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.dominantZone = dominantZone
        self.status = status
    }
}

struct ExpectedStep {
    var step: PrescribedStep
    var insideRepeat: Bool
}

struct LapGroup {
    var stepIndex: Int?
    var laps: [LapSummary]
}
