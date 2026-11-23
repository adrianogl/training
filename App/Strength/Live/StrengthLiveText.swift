import Foundation
import Insights

enum StrengthLiveText {
    static let onWatch = "● no relógio"
    static let time = "Tempo"
    static let heartRate = "FC"
    static let sets = "Séries"
    static let now = "Agora"
    static let workout = "Treino"
    static let rest = "Descanso"
    static let restOver = "Hora da série"
    static let paused = "Pausado no relógio"
    static let setColumn = "Série"
    static let doneColumn = "Feito"
    static let planColumn = "Plano"
    static let lastColumn = "Última"
    static let next = "próxima"
    static let none = "—"
    static let later = "depois"
    static let leftOut = "de fora"
    static let todayTitle = "Ao vivo · Força"
    static let doing = "Fazendo"
    static let finished = "Treino concluído"

    static func momentLabel(_ card: LiveStrengthCard) -> String {
        switch card.moment {
        case .doing: doing + " · série \(card.setNumber) de \(card.setCount)"
        case .resting: rest
        case .restOver: restOver + " \(card.setNumber) de \(card.setCount)"
        case .paused: paused
        case .finished: finished
        }
    }

    static func todayLine(_ card: LiveStrengthCard) -> String? {
        guard let name = card.shortName ?? card.exerciseName else { return nil }
        guard card.moment == .resting, let next = nextLine(card.target) else { return name + " · série \(card.setNumber) de \(card.setCount)" }
        return name + " · " + next
    }

    static func header(_ day: Date) -> String {
        "Força · " + day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "pt_BR")))
    }

    static func nowSubtitle(_ now: LiveStrengthNow) -> String {
        var parts = ["\(now.rounds) séries", target(now.exercise)]
        if now.restSeconds > 0 { parts.append("descanso " + clock(now.restSeconds)) }
        return parts.joined(separator: " · ")
    }

    static func itemDetail(_ item: LiveStrengthItem) -> String {
        let hasTarget = item.exercise.kind == .timed ? item.exercise.seconds != nil : item.exercise.reps != nil
        var parts = [hasTarget ? "\(item.rounds) × " + target(item.exercise) : "\(item.rounds) séries"]
        if let weight = item.exercise.weight, weight > 0 { parts.append(kilograms(weight) + " kg") }
        else if item.exercise.bodyweight { parts.append("peso corporal") }
        return parts.joined(separator: " · ")
    }

    static func nextLine(_ target: String?) -> String? {
        target.map { "próxima " + $0 + ($0.contains("×") ? " kg" : "") }
    }

    static func target(_ exercise: LiveStrengthExercise) -> String {
        let base = exercise.kind == .timed ? exercise.seconds.map { "\($0) s" } ?? none : exercise.reps.map { "\($0) reps" } ?? none
        return exercise.perSide ? base + " cada lado" : base
    }

    static func progress(_ item: LiveStrengthItem) -> String {
        "\(item.setsDone)/\(item.rounds)"
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func kilograms(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "pt_BR")))
    }
}
