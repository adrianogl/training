import Foundation

enum ComparisonText {
    static let currentLabel = "Este treino"

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale))
    }

    static func evolution(current: ComparisonRow, oldest: ComparisonRow) -> String? {
        guard let currentPace = current.secondsPerKilometer, let oldestPace = oldest.secondsPerKilometer else { return nil }
        let paceDelta = currentPace - oldestPace
        let paceSeconds = Int(abs(paceDelta).rounded())
        let pace: String
        if abs(paceDelta) < WorkoutDetailConstants.paceDeltaThreshold {
            pace = "Mesmo pace"
        } else {
            pace = paceDelta < 0 ? "\(paceSeconds) s/km mais rápido" : "\(paceSeconds) s/km mais lento"
        }
        let since = "em relação a \(oldest.dateText.trimmingCharacters(in: CharacterSet(charactersIn: ".")))"
        guard let currentHeartRate = current.heartRate, let oldestHeartRate = oldest.heartRate else {
            return "\(pace) \(since)."
        }
        let heartRateDelta = currentHeartRate - oldestHeartRate
        let beats = Int(abs(heartRateDelta).rounded())
        let heartRate: String
        if abs(heartRateDelta) < WorkoutDetailConstants.heartRateDeltaThreshold {
            heartRate = "FC igual"
        } else {
            heartRate = heartRateDelta < 0 ? "FC \(beats) bpm menor" : "FC \(beats) bpm maior"
        }
        return "\(pace), \(heartRate), \(since)."
    }
}
