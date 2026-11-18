import FITReader
import TrainingCore

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
    public var weatherFactor: Double?
    public var weatherRescued: Bool?

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
        status: BlockStatus,
        weatherFactor: Double? = nil,
        weatherRescued: Bool? = nil
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
        self.weatherFactor = weatherFactor
        self.weatherRescued = weatherRescued
    }

    public var weatherSpeed: Double? {
        avgSpeed.map { WeatherAdjustment.mildSpeed($0, factor: weatherFactor) }
    }
}

public typealias BlockKilometers = [Int: [WorkoutBlock]]

struct TrackPoint {
    var t: Double
    var distance: Double
    var heartRate: Int?
    var altitude: Double?
}

struct ExpectedStep {
    var step: PrescribedStep
    var insideRepeat: Bool
}

struct LapGroup {
    var stepIndex: Int?
    var laps: [LapSummary]
    var extra = false
}
