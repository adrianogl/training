public enum FindingGroup: String, Codable, Sendable {
    case positive, negative, attention
}

public enum FindingKind: String, Codable, Sendable {
    case blockInTarget, steadyPace, lowerHeartRateThanBefore, goodRecovery
    case blockOffTarget, stepIncomplete, paceFade
    case cardiacDrift, zoneAboveTarget, hardOnLowReadiness, highAcuteChronic
}

public enum FindingFact {
    public static let inTarget = "inTarget"
    public static let total = "total"
    public static let spread = "spread"
    public static let fade = "fade"
    public static let rise = "rise"
    public static let fromHR = "fromHR"
    public static let toHR = "toHR"
    public static let drop = "drop"
    public static let delta = "delta"
    public static let zone = "zone"
    public static let readiness = "readiness"
    public static let ratio = "ratio"
    public static let speed = "speed"
    public static let heartRate = "heartRate"
    public static let targetLow = "targetLow"
    public static let targetHigh = "targetHigh"
    public static let distance = "distance"
    public static let seconds = "seconds"
    public static let targetDistance = "targetDistance"
    public static let targetSeconds = "targetSeconds"
    public static let fastestPace = "fastestPace"
    public static let slowestPace = "slowestPace"
    public static let lastPace = "lastPace"
    public static let medianPace = "medianPace"
    public static let beforeHeartRate = "beforeHeartRate"
    public static let peak = "peak"
    public static let recovered = "recovered"
    public static let recoveryHeartRate = "recoveryHeartRate"
    public static let recoveryHighest = "recoveryHighest"
}

public struct Finding: Codable, Sendable, Equatable {
    public var group: FindingGroup
    public var kind: FindingKind
    public var blockOrdinal: Int?
    public var facts: [String: Double]

    public init(group: FindingGroup, kind: FindingKind, blockOrdinal: Int?, facts: [String: Double]) {
        self.group = group
        self.kind = kind
        self.blockOrdinal = blockOrdinal
        self.facts = facts
    }
}

public struct WorkoutAssessment: Codable, Sendable, Equatable {
    public var positives: [Finding]
    public var negatives: [Finding]
    public var attention: [Finding]

    public init(positives: [Finding], negatives: [Finding], attention: [Finding]) {
        self.positives = positives
        self.negatives = negatives
        self.attention = attention
    }
}

public struct AssessmentContext: Sendable {
    public var readinessScore: Int?
    public var acuteChronic: Double?
    public var previous: [[WorkoutBlock]]
    public var kilometers: BlockKilometers

    public init(readinessScore: Int? = nil, acuteChronic: Double? = nil, previous: [[WorkoutBlock]] = [], kilometers: BlockKilometers = [:]) {
        self.readinessScore = readinessScore
        self.acuteChronic = acuteChronic
        self.previous = previous
        self.kilometers = kilometers
    }
}
