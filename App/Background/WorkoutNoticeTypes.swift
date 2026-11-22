import Foundation

struct FinishedRun: Equatable, Sendable {
    let activityId: Int64
    let typeKey: String
    let start: Date
    let end: Date
}

struct PendingWorkout: Codable, Equatable, Sendable {
    let activityId: Int64
    let end: Date
}

struct PendingWorkoutQueue: Equatable {
    var items: [PendingWorkout] = []
}

struct ExpectedRun: Codable, Equatable, Sendable {
    let start: Date
    let until: Date
}

enum WorkoutNoticeCheck: Equatable {
    case now
    case after(Date)
}

enum WorkoutNoticeStatus: Equatable, Sendable {
    case ready(WorkoutNoticeContent)
    case waiting
    case unavailable
}
