import TrainingCore

public struct WorkoutOccurrence: Sendable {
    public var activityId: Int64
    public var day: Day
    public var blocks: [WorkoutBlock]

    public init(activityId: Int64, day: Day, blocks: [WorkoutBlock]) {
        self.activityId = activityId
        self.day = day
        self.blocks = blocks
    }
}

public struct BlockValue: Codable, Sendable, Equatable {
    public var speed: Double?
    public var heartRate: Int?
    public var status: BlockStatus

    public init(speed: Double?, heartRate: Int?, status: BlockStatus) {
        self.speed = speed
        self.heartRate = heartRate
        self.status = status
    }
}

public struct BlockComparison: Codable, Sendable, Equatable {
    public var label: String
    public var values: [Int64: BlockValue]

    public init(label: String, values: [Int64: BlockValue]) {
        self.label = label
        self.values = values
    }
}

public struct WorkoutComparison: Codable, Sendable, Equatable {
    public var occurrences: [Int64]
    public var blocks: [BlockComparison]
    public var sameStructure: Bool
    public var activeSpeedDelta: Double?
    public var activeHeartRateDelta: Double?

    public init(occurrences: [Int64], blocks: [BlockComparison], sameStructure: Bool, activeSpeedDelta: Double?, activeHeartRateDelta: Double?) {
        self.occurrences = occurrences
        self.blocks = blocks
        self.sameStructure = sameStructure
        self.activeSpeedDelta = activeSpeedDelta
        self.activeHeartRateDelta = activeHeartRateDelta
    }
}
