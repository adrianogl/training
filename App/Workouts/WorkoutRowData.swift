import Foundation
import GarminAPI
import TrainingCore

struct WorkoutRowData: Identifiable, Hashable {
    let activityId: Int64
    let title: String
    let names: [String]
    let dayIso: String
    let dateText: String
    let distanceText: String?
    let durationText: String?
    let paceText: String?
    let hasPrescription: Bool
    var score: Int?
    let kilometers: Double?
    let zoneShares: [Double]
    let weekStart: Day
    var isStrength = false
    var recordPill: String?
    var goalPill: String?

    var id: Int64 { activityId }
}

struct WorkoutWeek: Identifiable, Hashable {
    let start: Day
    let kilometers: Double
    let rows: [WorkoutRowData]
    var runCount: Int
    var plannedKilometers: Double?
    var strengthCount = 0

    var plannedProgress: Double? {
        guard let plannedKilometers, plannedKilometers > 0 else { return nil }
        return min(kilometers / plannedKilometers, 1)
    }

    var id: Day { start }
}

enum WorkoutSelection: Hashable, Codable {
    case activity(Int64)
    case planned(Int64)
    case strength(Int64)
}

struct TrainerPlannedStrength: Equatable {
    let workout: StrengthWorkout
    let sessionId: UUID
}

enum WorkoutPlannedItem: Identifiable {
    case run(PlannedWorkout)
    case strength(StrengthWorkout)

    var id: String {
        switch self {
        case .run(let plan): "run-\(plan.id)"
        case .strength(let workout): "strength-\(workout.id)-\(workout.day)"
        }
    }

    var day: String {
        switch self {
        case .run(let plan): plan.day
        case .strength(let workout): workout.day
        }
    }
}

struct PlannedVisibility: Equatable {
    let visible: [PlannedWorkout]
    let fromPlanIds: Set<Int64>
}

enum WorkoutKindFilter: String, CaseIterable, Identifiable {
    case all, run, strength

    var id: String { rawValue }
}
