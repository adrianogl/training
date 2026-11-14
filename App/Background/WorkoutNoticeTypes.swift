import Foundation

struct FinishedWorkout: Equatable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
}

struct PendingWorkout: Codable, Equatable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
}

struct PendingWorkoutQueue: Equatable {
    var items: [PendingWorkout] = []
}
