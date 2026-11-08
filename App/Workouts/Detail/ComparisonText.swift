import Foundation

enum ComparisonText {
    static let currentLabel = "Este treino"

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale))
    }

    static let commonBlocksNotice = "A estrutura do treino mudou entre as ocorrências. A comparação usa só os blocos em comum."
    static let ownActiveBlocksNotice = "A estrutura mudou; pace e FC são a média dos blocos ativos de cada treino."

    static func evolution(paceDelta: Double, heartRateDelta: Double?, oldestDate: String) -> String {
        let paceSeconds = Int(abs(paceDelta).rounded())
        let pace: String
        if abs(paceDelta) < WorkoutDetailConstants.paceDeltaThreshold {
            pace = "Mesmo pace"
        } else {
            pace = paceDelta < 0 ? "\(paceSeconds) s/km mais rápido" : "\(paceSeconds) s/km mais lento"
        }
        let since = "em relação a \(oldestDate.trimmingCharacters(in: CharacterSet(charactersIn: ".")))"
        guard let heartRateDelta else { return "\(pace) \(since)." }
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
