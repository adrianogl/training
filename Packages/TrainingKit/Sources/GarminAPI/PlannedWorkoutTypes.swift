import Foundation

public enum PlannedStepKind: String, Sendable, Equatable {
    case warmup, active, recovery, cooldown, rest, other
}

public enum PlannedTarget: Sendable, Equatable {
    case pace(fastest: Double, slowest: Double)
    case heartRate(low: Double, high: Double)
    case zone(Int)
}

public struct PlannedStep: Sendable, Equatable {
    public var kind: PlannedStepKind
    public var seconds: Double?
    public var meters: Double?
    public var target: PlannedTarget?
    public var repeats: Int
    public var children: [PlannedStep]

    public init(kind: PlannedStepKind, seconds: Double? = nil, meters: Double? = nil, target: PlannedTarget? = nil, repeats: Int = 1, children: [PlannedStep] = []) {
        self.kind = kind
        self.seconds = seconds
        self.meters = meters
        self.target = target
        self.repeats = repeats
        self.children = children
    }

    public var flattened: [PlannedStep] {
        guard !children.isEmpty else { return [self] }
        return Array(repeating: children.flatMap(\.flattened), count: max(repeats, 1)).flatMap { $0 }
    }
}

public struct PlannedWorkout: Sendable, Equatable, Identifiable {
    public var id: Int64
    public var day: String
    public var title: String
    public var estimatedSeconds: Double?
    public var estimatedMeters: Double?
    public var steps: [PlannedStep]

    public init(id: Int64, day: String, title: String, estimatedSeconds: Double?, estimatedMeters: Double?, steps: [PlannedStep]) {
        self.id = id
        self.day = day
        self.title = title
        self.estimatedSeconds = estimatedSeconds
        self.estimatedMeters = estimatedMeters
        self.steps = steps
    }
}

struct CalendarDTO: Decodable {
    struct Item: Decodable {
        let itemType: String?
        let date: String?
        let title: String?
        let workoutId: Int64?
        let sportTypeKey: String?
    }

    let calendarItems: [Item]
}

struct WorkoutDTO: Decodable {
    struct Segment: Decodable {
        let workoutSteps: [StepDTO]?
    }

    let workoutId: Int64
    let workoutName: String?
    let estimatedDistanceInMeters: Double?
    let estimatedDurationInSecs: Double?
    let workoutSegments: [Segment]?
}

final class StepDTO: Decodable {
    struct Key: Decodable {
        let stepTypeKey: String?
        let conditionTypeKey: String?
        let workoutTargetTypeKey: String?
    }

    let type: String?
    let stepType: Key?
    let endCondition: Key?
    let endConditionValue: Double?
    let targetType: Key?
    let targetValueOne: Double?
    let targetValueTwo: Double?
    let zoneNumber: Int?
    let numberOfIterations: Int?
    let workoutSteps: [StepDTO]?
}
