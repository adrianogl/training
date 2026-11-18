import Foundation
import TrainingCore

public enum HealthWorkoutKind: String, Sendable, Equatable {
    case run, walk, strength, other
}

public struct HealthWorkout: Sendable, Equatable {
    public var id: UUID
    public var kind: HealthWorkoutKind
    public var start: Date
    public var end: Date
    public var duration: Double
    public var distanceMeters: Double?
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?
    public var elevationGain: Double?
    public var averagePower: Double?
    public var averageCadence: Double?
    public var averageGroundContactMs: Double?
    public var averageVerticalOscillationCm: Double?
    public var averageStrideMeters: Double?
    public var vo2max: Double?
    public var indoor: Bool

    public init(
        id: UUID, kind: HealthWorkoutKind, start: Date, end: Date, duration: Double, distanceMeters: Double? = nil,
        averageHeartRate: Double? = nil, maxHeartRate: Double? = nil, elevationGain: Double? = nil, averagePower: Double? = nil,
        averageCadence: Double? = nil, averageGroundContactMs: Double? = nil, averageVerticalOscillationCm: Double? = nil,
        averageStrideMeters: Double? = nil, vo2max: Double? = nil, indoor: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.elevationGain = elevationGain
        self.averagePower = averagePower
        self.averageCadence = averageCadence
        self.averageGroundContactMs = averageGroundContactMs
        self.averageVerticalOscillationCm = averageVerticalOscillationCm
        self.averageStrideMeters = averageStrideMeters
        self.vo2max = vo2max
        self.indoor = indoor
    }
}

public struct HealthPoint: Sendable, Equatable {
    public var date: Date
    public var value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct HealthRoutePoint: Sendable, Equatable {
    public var date: Date
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double?

    public init(date: Date, latitude: Double, longitude: Double, altitude: Double? = nil) {
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }
}

public struct HealthLap: Sendable, Equatable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public struct HealthSeries: Sendable, Equatable {
    public var heartRate: [HealthPoint]
    public var distance: [HealthPoint]
    public var speed: [HealthPoint]
    public var cadence: [HealthPoint]
    public var groundContactMs: [HealthPoint]
    public var route: [HealthRoutePoint]
    public var laps: [HealthLap]

    public init(
        heartRate: [HealthPoint] = [], distance: [HealthPoint] = [], speed: [HealthPoint] = [], cadence: [HealthPoint] = [],
        groundContactMs: [HealthPoint] = [], route: [HealthRoutePoint] = [], laps: [HealthLap] = []
    ) {
        self.heartRate = heartRate
        self.distance = distance
        self.speed = speed
        self.cadence = cadence
        self.groundContactMs = groundContactMs
        self.route = route
        self.laps = laps
    }
}

public struct HealthSleepNight: Sendable, Equatable {
    public var day: Day
    public var end: Date
    public var asleepSeconds: Double
    public var deepSeconds: Double
    public var remSeconds: Double
    public var coreSeconds: Double
    public var awakeSeconds: Double

    public init(day: Day, end: Date, asleepSeconds: Double, deepSeconds: Double, remSeconds: Double, coreSeconds: Double, awakeSeconds: Double) {
        self.day = day
        self.end = end
        self.asleepSeconds = asleepSeconds
        self.deepSeconds = deepSeconds
        self.remSeconds = remSeconds
        self.coreSeconds = coreSeconds
        self.awakeSeconds = awakeSeconds
    }
}

public protocol HealthReading: Sendable {
    func workouts(from: Date, to: Date) async throws -> [HealthWorkout]
    func series(for workout: HealthWorkout) async throws -> HealthSeries
    func restingHeartRate(from: Day, to: Day) async throws -> [Day: Double]
    func nightlyHRV(from: Day, to: Day) async throws -> [Day: Double]
    func sleep(from: Day, to: Day) async throws -> [HealthSleepNight]
}
