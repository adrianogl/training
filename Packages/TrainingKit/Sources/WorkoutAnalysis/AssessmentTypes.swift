import FITReader
import TrainingCore

public enum FindingGroup: String, Codable, Sendable {
    case positive, negative, attention
}

public enum FindingKind: String, Codable, Sendable {
    case blockInTarget, steadyPace, lowerHeartRateThanBefore, goodRecovery
    case blockOffTarget, stepIncomplete, paceFade
    case cardiacDrift, zoneAboveTarget, hardOnLowReadiness, highAcuteChronic
    case climbSlower, descentFaster
    case weatherSlower, windAgainst, runFormFade
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
    public static let fadeKilometer = "fadeKilometer"
    public static let slowdown = "slowdown"
    public static let heartRateRise = "heartRateRise"
    public static let pauseCount = "pauseCount"
    public static let pauseKilometer = "pauseKilometer"
    public static let pauseSeconds = "pauseSeconds"
    public static let fromKilometer = "fromKilometer"
    public static let toKilometer = "toKilometer"
    public static let climb = "climb"
    public static let descent = "descent"
    public static let pace = "pace"
    public static let flatPace = "flatPace"
    public static let flatAdjusted = "flatAdjusted"
    public static let lastClimb = "lastClimb"
    public static let temperature = "temperature"
    public static let dewPoint = "dewPoint"
    public static let weatherFactor = "weatherFactor"
    public static let cold = "cold"
    public static let mildPace = "mildPace"
    public static let count = "count"
    public static let windSpeed = "windSpeed"
    public static let headwind = "headwind"
    public static let cadenceFrom = "cadenceFrom"
    public static let cadenceTo = "cadenceTo"
    public static let stanceFrom = "stanceFrom"
    public static let stanceTo = "stanceTo"
    public static let sleepSeconds = "sleepSeconds"
    public static let sleepScore = "sleepScore"
    public static let hrvLow = "hrvLow"
    public static let bodyBattery = "bodyBattery"
    public static let previousDay = "previousDay"
    public static let sunny = "sunny"
    public static let hotSessions = "hotSessions"
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
    public var continuity: RunContinuity?
    public var weather: WeatherEffect?
    public var samples: [FITSample]
    public var day: DayCondition?

    public init(
        readinessScore: Int? = nil,
        acuteChronic: Double? = nil,
        previous: [[WorkoutBlock]] = [],
        kilometers: BlockKilometers = [:],
        continuity: RunContinuity? = nil,
        weather: WeatherEffect? = nil,
        samples: [FITSample] = [],
        day: DayCondition? = nil
    ) {
        self.readinessScore = readinessScore
        self.acuteChronic = acuteChronic
        self.previous = previous
        self.kilometers = kilometers
        self.continuity = continuity
        self.weather = weather
        self.samples = samples
        self.day = day
    }
}

public enum PreviousDayLoad: Int, Codable, Sendable {
    case threshold = 1, intervals, long, legs
}

public struct DayCondition: Sendable, Equatable {
    public var sleepSeconds: Int?
    public var sleepScore: Int?
    public var hrvBelowBalanced: Bool
    public var bodyBattery: Int?
    public var previousDay: PreviousDayLoad?

    public init(sleepSeconds: Int? = nil, sleepScore: Int? = nil, hrvBelowBalanced: Bool = false, bodyBattery: Int? = nil, previousDay: PreviousDayLoad? = nil) {
        self.sleepSeconds = sleepSeconds
        self.sleepScore = sleepScore
        self.hrvBelowBalanced = hrvBelowBalanced
        self.bodyBattery = bodyBattery
        self.previousDay = previousDay
    }
}
