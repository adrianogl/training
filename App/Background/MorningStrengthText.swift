import Foundation
import Insights

enum MorningStrengthText {
    static let prefix = "Força:"
    static let adjustedPrefix = "Força ajustada:"
    static let minutesFormat = "%d min"

    static func line(mfitTitle: String?, trainer: GeneratedStrengthWorkout?) -> String? {
        var parts: [String] = []
        if let mfitTitle, !mfitTitle.isEmpty {
            parts.append("\(prefix) \(mfitTitle).")
        }
        if let trainer, !trainer.exercises.isEmpty {
            let adjusted = trainer.adjustments.contains { if case .pain = $0 { false } else { true } }
            let focus = TrainerStrengthText.focusName(trainer.group).lowercased()
            let minutes = String(format: minutesFormat, Int(trainer.estimatedMinutes.rounded()))
            parts.append("\(adjusted ? adjustedPrefix : prefix) \(focus), \(minutes).")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
