import Foundation
import Insights
import TrainingCore
import WorkoutAnalysis

extension TrainerText {
    static let planTab = "Plano"
    static let compareTab = "Comparar"
    static let compareColumns = "seu treinador · beta"
    static let externalLabel = "Seu treinador"
    static let betaLabel = "Beta"
    static let noWorkoutLabel = "folga"
    static let scoreboardWeeks = "Semanas"
    static let acceptReadiness = "Aceitar"
    static let keepReadiness = "Manter"
    static let todayRestDay = "Folga hoje"
    static let todayDone = "feito ✓"
    static let minus = "−"

    static func scoreboardTitle(_ week: Int) -> String { "Placar · semana \(week)" }

    static func scoreboardKilometers(_ board: TrainerScoreboard) -> String {
        "\(kilometersNumber(board.doneMeters))/\(kilometersNumber(board.plannedMeters)) km"
    }

    static func scoreboardQuality(_ board: TrainerScoreboard) -> String? {
        board.qualityTotal > 0 ? "\(board.qualityOnTarget) de \(board.qualityTotal) no alvo" : nil
    }

    static func scoreboardQualityShort(_ board: TrainerScoreboard) -> String? {
        board.qualityTotal > 0 ? "\(board.qualityOnTarget)/\(board.qualityTotal) no alvo" : nil
    }

    static func scoreboardLong(_ board: TrainerScoreboard) -> String? {
        guard let closed = board.longClosed else { return nil }
        let mode = board.longBlocks ? "em blocos" : "contínuo"
        return "Longão \(mode) \(closed ? "fechou" : "não fechou")"
    }

    static func predictionDelta(_ seconds: Double) -> String {
        let rounded = Int(seconds.rounded())
        let sign = rounded < 0 ? minus : "+"
        let value = abs(rounded)
        return value >= 120 ? "\(sign)\(WorkoutFormat.clock(Double(value)))" : "\(sign)\(value) s"
    }

    static func scoreboardPrediction(_ board: TrainerScoreboard) -> String? {
        guard let seconds = board.predictionDeltaSeconds, let meters = board.predictionMeters else { return nil }
        let label = meters >= 10_000 ? "\(Int((meters / TrainerConstants.metersPerKilometer).rounded())) km" : distance(meters)
        return "\(predictionDelta(seconds)) previsão \(label)"
    }

    static func scoreboardRow(_ board: TrainerScoreboard) -> String {
        [
            "S\(board.weekIndex)", scoreboardKilometers(board), scoreboardQualityShort(board),
            board.predictionDeltaSeconds.map(predictionDelta),
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    static func compareSummaryKilometers(_ week: TrainerComparisonWeek) -> String {
        "\(kilometersNumber(week.externalMeters)) · \(kilometersNumber(week.betaMeters)) km"
    }

    static func compareSummaryQuality(_ week: TrainerComparisonWeek) -> String {
        "\(week.externalQuality) · \(week.betaQuality) qualidade"
    }

    static func compareSummarySame(_ week: TrainerComparisonWeek) -> String {
        "\(week.sameKindDays) de \(week.comparedDays) dias iguais"
    }

    static func matchWord(_ match: TrainerComparisonMatch) -> String {
        switch match {
        case .same: "igual"
        case .similar: "parecido"
        case .different: "diferente"
        }
    }

    static func compareDayTitle(_ day: TrainerComparisonDay) -> String {
        let kind = day.externalKind ?? day.beta?.kind
        let name = (kind.map(kindName) ?? "").lowercased()
        return "\(weekdayShort(day.day)) \(day.day.day) · \(name) \(matchWord(day.match))"
    }

    static func compareDone(_ day: TrainerComparisonDay) -> String? {
        guard let run = day.run else { return nil }
        var text = "Você fez \(distance(run.meters))"
        if let pace = runPace(run) { text += " · \(pace)" }
        switch day.closer {
        case .external: text += " → mais perto do seu treinador"
        case .beta: text += " → mais perto do beta"
        case .tie: text += " → os dois ficaram perto"
        case nil: break
        }
        return text
    }

    static func readinessSuggestionText(_ suggestion: TrainerReadinessSuggestion) -> String {
        let head = suggestion.factor.map { "Prontidão \(suggestion.score) com \($0.name) \($0.value)." } ?? "Prontidão \(suggestion.score)."
        let light = "rodagem leve de \(TrainerConstants.readinessEasyKilometers) km hoje"
        if suggestion.swaps { return "\(head) Sugestão: \(light) e \(suggestion.workoutTitle) amanhã." }
        return "\(head) Sugestão: \(light) e manter o resto da semana."
    }
}
