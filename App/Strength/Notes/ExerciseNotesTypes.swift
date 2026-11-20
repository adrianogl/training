import Foundation

struct ExerciseNote: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let exercise: ExerciseKey
    var text: String
    let createdAt: Date
    var updatedAt: Date
    var deleted: Bool
}
