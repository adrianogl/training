import Foundation

enum ExerciseFeedbackVerdict: String, Codable, Sendable {
    case matches, doesNotMatch
}

enum ExerciseFeedbackStatus: String, Codable, Sendable {
    case pending, resolved
}

struct ExerciseFeedback: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let exercise: ExerciseKey
    let exerciseName: String
    let mediaId: String
    var verdict: ExerciseFeedbackVerdict
    var chosenMediaId: String?
    var noneMatched: Bool
    var note: String?
    let createdAt: Date
    var updatedAt: Date
    let workoutDay: String?
    var status: ExerciseFeedbackStatus
    var resolution: String?
    var resolvedIn: String?
    var undoes: UUID? = nil
}
