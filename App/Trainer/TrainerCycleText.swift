import Foundation
import Insights
import WorkoutAnalysis

enum TrainerCycleText {
    static let bannerTitle = "Ciclo concluído."
    static let bannerAction = "Ver análise"
    static let openAnalysis = "Ver análise do ciclo"
    static let analysisTitle = "Análise do ciclo"
    static let resultTitle = "Resultado do ciclo"
    static let nextTitle = "Próximo ciclo"
    static let raceTitle = "Prova"
    static let volumeTitle = "Volume"
    static let keyTitle = "Treinos-chave"
    static let bodyTitle = "Como o corpo respondeu"
    static let formTitle = "Forma"
    static let endMenu = "Encerrar ciclo agora"
    static let endTitle = "Encerrar o ciclo agora?"
    static let endConfirm = "Encerrar"
    static let createWithSuggestion = "Criar próximo plano com esse volume"
    static let applySuggestion = "Aplicar ao plano"
    static let chooseOther = "Escolher outro volume"
    static let previousTitle = "Ciclos anteriores"
    static let ruleTitle = "Como a sugestão é decidida"
    static let ruleSubtitle = "Volume cumprido, prontidão e forma"
    static let noReadiness = "Sem dados de prontidão neste ciclo"
    static let chartDone = "feito"
    static let chartPlanned = "previsto"
    static let chartBelow = "abaixo de 80%"
    static let keyLong = "Longões"
    static let keyThreshold = "Limiar"
    static let keyVo2 = "VO2 máx"
    static let keyMediumLong = "Média-longa"
    static let readinessTitle = "Prontidão média"
    static let lowReadinessTitle = "Dias com prontidão baixa"
    static let lightWeeksTitle = "Semanas leves extras"
    static let lightWeeksCaption = "fora do previsto"
    static let longsMissedTitle = "Longões cortados"
    static let ruleLines = [
        "Aumenta quando cumpriu 90% ou mais do volume, a prontidão ficou estável e a forma melhorou. O pico sobe até 8%.",
        "Mantém quando cumpriu entre 75% e 90%, ou cumpriu tudo mas a forma não andou.",
        "Diminui quando cumpriu menos de 75%, a prontidão caiu 8 pontos ou mais, ou houve 2 semanas leves fora do previsto. O pico desce 10%.",
    ]

    static func banner(_ review: TrainerCycleReview, dated: Bool) -> String {
        let count = review.weeks.count
        if review.endedEarly {
            let weeks = count == 1 ? "da 1 semana concluída" : "das \(count) semanas concluídas"
            return "Você encerrou o ciclo. Veja a análise \(weeks)."
        }
        if dated { return "A prova terminou. Veja como foi e o volume sugerido." }
        return "Fechou \(count) \(count == 1 ? "semana" : "semanas"). Veja como foi e o volume sugerido."
    }

    static func verdictTitle(_ verdict: TrainerCycleVerdict) -> String {
        switch verdict {
        case .increase: "Aumentar o volume"
        case .keep: "Manter o volume"
        case .decrease: "Diminuir o volume"
        }
    }

    static func suggestionLine(_ review: TrainerCycleReview, dated: Bool) -> String {
        let current = km(dated ? review.currentPeakMeters : review.currentStartMeters)
        let suggested = km(dated ? review.suggestedPeakMeters : review.suggestedStartMeters)
        switch (review.verdict, dated) {
        case (.increase, true): return "Sugestão: aumentar o pico de \(current) para \(suggested) km"
        case (.keep, true): return "Sugestão: manter o pico em \(current) km"
        case (.decrease, true): return "Sugestão: diminuir o pico de \(current) para \(suggested) km"
        case (.increase, false): return "Sugestão: aumentar de \(current) para \(suggested) km"
        case (.keep, false): return "Sugestão: manter \(current) km"
        case (.decrease, false): return "Sugestão: diminuir de \(current) para \(suggested) km"
        }
    }

    static func volumes(_ review: TrainerCycleReview, dated: Bool) -> String {
        let startLabel = dated ? "Início" : "Base"
        let peakLabel = "pico"
        let start = km(review.currentStartMeters)
        let peak = km(review.currentPeakMeters)
        if review.verdict == .keep { return "\(startLabel) \(start) km · \(peakLabel) \(peak) km, como neste ciclo" }
        return "\(startLabel) \(start) → \(km(review.suggestedStartMeters)) km · \(peakLabel) \(peak) → \(km(review.suggestedPeakMeters)) km"
    }

    static func reason(_ reason: TrainerCycleReason) -> String {
        switch reason {
        case .volume(let share, let weeksBelow):
            let below = weeksBelow == 0
                ? "nenhuma semana abaixo do previsto"
                : "\(weeksBelow) \(weeksBelow == 1 ? "semana" : "semanas") abaixo do previsto"
            return "Cumpriu \(Int((share * 100).rounded()))% do volume, \(below)."
        case .readiness(let first, let last):
            return "Prontidão média foi de \(Int(first.rounded())) para \(Int(last.rounded()))."
        case .lightWeeks(let count):
            return "\(count) \(count == 1 ? "semana leve" : "semanas leves") fora do previsto."
        case .prediction(let change):
            let verb = change.last < change.first ? "caiu" : "subiu"
            return "A previsão de \(distanceName(change.meters)) \(verb) \(WorkoutFormat.clock(abs(change.first - change.last)))."
        case .race(let seconds, let goal):
            let side = seconds <= goal ? "abaixo" : "acima"
            return "Fez a prova \(WorkoutFormat.clock(abs(goal - seconds))) \(side) da meta."
        case .tooShort(let weeks):
            return "Só \(weeks) \(weeks == 1 ? "semana concluída" : "semanas concluídas"), pouco para mudar o volume."
        case .noProgress:
            return "Cumpriu o volume, mas a previsão não melhorou."
        }
    }

    static func endMessage(weeks: Int) -> String {
        let used = weeks == 1 ? "a 1 semana já concluída" : "as \(weeks) semanas já concluídas"
        return "A análise vai usar \(used). O plano atual para de gerar treinos."
    }

    static func summaryLine(_ summary: TrainerCycleSummary) -> String {
        let before = km(summary.beforePeakMeters)
        let after = km(summary.afterPeakMeters)
        var line: String
        switch summary.verdict {
        case .increase: line = "Aumentou de \(before) para \(after) km"
        case .keep: line = "Manteve \(before) km"
        case .decrease: line = "Diminuiu de \(before) para \(after) km"
        }
        if let seconds = summary.resultSeconds { line += " · \(WorkoutFormat.clock(seconds))" }
        return line
    }

    static func count(_ count: TrainerCycleCount) -> String {
        "\(count.done) de \(count.total)"
    }

    static func longest(_ meters: Double) -> String {
        "Maior longão feito: \(km(meters)) km"
    }

    static func volumeDone(_ review: TrainerCycleReview) -> String {
        "\(wholeKm(review.doneMeters)) de \(wholeKm(review.plannedMeters)) km"
    }

    static func volumeShare(_ review: TrainerCycleReview) -> String {
        "\(Int((review.doneShare * 100).rounded()))% do previsto"
    }

    static func goal(_ seconds: Double) -> String {
        "meta \(WorkoutFormat.clock(seconds))"
    }

    static func raceDifference(seconds: Double, goal: Double) -> String {
        let side = seconds <= goal ? "abaixo" : "acima"
        return "\(WorkoutFormat.clock(abs(goal - seconds))) \(side) da meta"
    }

    static func readinessCaption(_ first: Double) -> String {
        "\(Int(first.rounded())) no início"
    }

    static func lowReadinessCaption(_ limit: Int) -> String {
        "abaixo de \(limit)"
    }

    static func longsMissedCaption(_ total: Int) -> String {
        "de \(total) \(total == 1 ? "longão" : "longões")"
    }

    static func readiness(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    static func predictionTitle(_ meters: Double) -> String {
        "Previsão \(distanceName(meters))"
    }

    static func predictionCaption(_ change: TrainerCycleChange) -> String {
        "era \(WorkoutFormat.clock(change.first)) no início"
    }

    static func predictionDelta(_ change: TrainerCycleChange) -> String {
        let delta = change.last - change.first
        if delta.rounded() == 0 { return "sem mudança" }
        return "\(delta < 0 ? "−" : "+")\(WorkoutFormat.clock(abs(delta)))"
    }

    static func clock(_ seconds: Double) -> String {
        WorkoutFormat.clock(seconds)
    }

    static func resultValue(_ review: TrainerCycleReview, goalMeters: Double?) -> String {
        if let seconds = review.raceSeconds { return WorkoutFormat.clock(seconds) }
        if let prediction = referencePrediction(review, goalMeters: goalMeters) { return WorkoutFormat.clock(prediction.last) }
        return volumeDone(review)
    }

    static func resultCaption(_ review: TrainerCycleReview, goalMeters: Double?) -> String {
        if review.raceSeconds != nil { return review.goalSeconds.map(goal) ?? volumeDone(review) }
        if let prediction = referencePrediction(review, goalMeters: goalMeters) {
            return "\(predictionTitle(prediction.meters).lowercased()) · \(volumeDone(review))"
        }
        return volumeShare(review)
    }

    private static func referencePrediction(_ review: TrainerCycleReview, goalMeters: Double?) -> TrainerCycleChange? {
        let reference = goalMeters ?? TrainerCycleConstants.referencePredictionMeters
        return review.predictions.min { abs($0.meters - reference) < abs($1.meters - reference) }
    }

    private static func wholeKm(_ meters: Double) -> Int {
        Int((meters / 1_000).rounded())
    }

    private static func km(_ meters: Double) -> String {
        TrainerText.kilometersNumber(meters)
    }

    private static func distanceName(_ meters: Double) -> String {
        switch meters {
        case 5_000: "5 km"
        case 10_000: "10 km"
        case 21_097.5: "meia"
        case 42_195: "maratona"
        default: "\(km(meters)) km"
        }
    }
}
