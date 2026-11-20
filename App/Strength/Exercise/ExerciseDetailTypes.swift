import Foundation
import Insights
import SwiftUI

struct ExerciseDetailInput: Equatable, Identifiable {
    let key: ExerciseKey
    let name: String
    let dose: String
    let load: String?
    let suggestedLoad: SuggestedLoad?
    let pattern: MovementPattern?
    let mfitNote: String?
    let workoutDay: String?
    var rest: String? = nil
    var showsFirstTime = false

    var id: String { "\(key)|\(name)" }
}

enum ExerciseFeedbackPanel: Equatable {
    case question, alternatives, drawingNote
}

enum ExerciseVerdictState: Equatable {
    case unrated
    case matched(ExerciseFeedback)
    case chosen(ExerciseFeedback)
    case rejected(ExerciseFeedback)
}

struct ExerciseNoteDraft: Equatable {
    var id: UUID?
    var text: String
}

extension EnvironmentValues {
    @Entry var exerciseFeedbackStore: ExerciseFeedbackStore?
    @Entry var exerciseNotesStore: ExerciseNotesStore?
}
