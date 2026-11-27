import Foundation
import TrainingCore

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
    public var secondaryTarget: PlannedTarget?
    public var repeats: Int
    public var children: [PlannedStep]

    public init(kind: PlannedStepKind, seconds: Double? = nil, meters: Double? = nil, target: PlannedTarget? = nil, secondaryTarget: PlannedTarget? = nil, repeats: Int = 1, children: [PlannedStep] = []) {
        self.kind = kind
        self.seconds = seconds
        self.meters = meters
        self.target = target
        self.secondaryTarget = secondaryTarget
        self.repeats = repeats
        self.children = children
    }

    public var flattened: [PlannedStep] {
        guard !children.isEmpty else { return [self] }
        return Array(repeating: children.flatMap(\.flattened), count: max(repeats, 1)).flatMap { $0 }
    }

    public static func activeBlocks(_ steps: [PlannedStep]) -> Int {
        let flat = steps.flatMap(\.flattened)
        return flat.indices.filter { index in
            flat[index].kind == .active && !(index > 0 && flat[index - 1].kind == .active && flat[index - 1].target == flat[index].target)
        }.count
    }

    public static func isSplitContinuous(_ steps: [PlannedStep]) -> Bool {
        let actives = steps.flatMap(\.flattened).filter { $0.kind == .active }.count
        return actives > 1 && activeBlocks(steps) == 1
    }
}

public struct ScheduledWorkoutRef: Sendable, Equatable {
    public let workoutId: Int64
    public let title: String
    public let day: Day
}

public struct PlannedWorkout: Sendable, Equatable, Identifiable {
    public var id: Int64
    public var day: String
    public var title: String
    public var estimatedSeconds: Double?
    public var estimatedMeters: Double?
    public var steps: [PlannedStep]
    public var provider: String?

    public init(id: Int64, day: String, title: String, estimatedSeconds: Double?, estimatedMeters: Double?, steps: [PlannedStep], provider: String? = nil) {
        self.id = id
        self.day = day
        self.title = title
        self.estimatedSeconds = estimatedSeconds
        self.estimatedMeters = estimatedMeters
        self.steps = steps
        self.provider = provider
    }
}

struct CalendarDTO: Decodable {
    struct Item: Decodable {
        struct EventTime: Decodable {
            let startTimeHhMm: String?
        }

        struct Target: Decodable {
            let value: Double?
            let unit: String?
            let unitType: String?
        }

        let id: Int64?
        let itemType: String?
        let date: String?
        let title: String?
        let workoutId: Int64?
        let sportTypeKey: String?
        var isRace: Bool? = nil
        var activityTypeId: Int? = nil
        var eventTimeLocal: EventTime? = nil
        var completionTarget: Target? = nil
        var courseId: Int64? = nil
        var url: String? = nil
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
    var workoutProvider: String? = nil
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
    let secondaryTargetType: Key?
    let secondaryTargetValueOne: Double?
    let secondaryTargetValueTwo: Double?
    let secondaryZoneNumber: Int?
    let numberOfIterations: Int?
    let workoutSteps: [StepDTO]?
    let description: String?
    let category: String?
    let exerciseName: String?
}
