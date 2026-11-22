import Foundation
import Insights

enum TrainerDaysText {
    static let runsTitle = "Corridas por semana"
    static let optionalTitle = "Treino opcional"
    static let optionalHint = "Conta no volume da semana."
    static let outAndBackTitle = "Ida e volta"
    static let outAndBackHint = "Km par e um bloco termina na metade, para virar e voltar."
    static let offTitle = "Dia off"
    static let offHint = "Nunca entra corrida nesse dia. A força continua onde está."
    static let longTitle = "Dia do longão"
    static let suggestionTitle = "Sugestão"
    static let allRules = "segue todas as regras"
    static let backToSuggestion = "Voltar à sugestão"
    static let alternatingShort = "Lim/VO2"
    static let noKilometers = "—"

    static func runsDetail(runs: Int, optional: Bool) -> String {
        optional ? "\(runs - 1) fixas + 1 opcional" : "\(runs) fixas"
    }

    static let volumeRangeTitle = "Volume sugerido"

    static func runsLabel(_ runs: Int) -> String {
        "\(runs) corridas"
    }

    static func axisValue(_ meters: Double) -> String {
        "\(Int((meters / 1_000).rounded())) km"
    }

    static func rangeValue(_ range: TrainerVolumeRange) -> String {
        "\(Int((range.minimum / 1_000).rounded()))–\(Int((range.comfortable / 1_000).rounded())) km"
    }

    static func volumeRangeCaption(range: TrainerVolumeRange?, runs: Int, peakMeters: Double, suggestedRuns: Int?) -> String {
        let peak = Int((peakMeters / 1_000).rounded())
        guard let range else { return "" }
        if range.fitsComfortably(peakMeters) { return "Seu pico de \(peak) km fica no confortável com \(runs) corridas." }
        let comfortable = Int((range.comfortable / 1_000).rounded())
        let minimum = Int((range.minimum / 1_000).rounded())
        let base = peakMeters > range.comfortable
            ? "Com \(runs) corridas, o confortável vai até \(comfortable) km."
            : "Com \(runs) corridas, a semana começa em \(minimum) km."
        guard let suggestedRuns else { return "\(base) Toque numa linha para comparar." }
        return "\(base) Seu pico de \(peak) km cabe melhor em \(suggestedRuns) corridas. Toque numa linha para escolher."
    }

    static let extraDayTitle = "Um dia a mais de corrida?"
    static func extraDayHint(_ suggestion: TrainerExtraDay) -> String {
        let place = "O novo dia entra numa folga, longe da força de pernas."
        guard suggestion.nextWeekMeters > suggestion.currentWeekMeters else { return "\(place) O volume da semana não muda." }
        return "\(place) Com \(suggestion.preference.runs) corridas, a semana chega a \(kilometers(suggestion.nextWeekMeters)) dos \(kilometers(suggestion.weekMeters)) do plano."
    }

    static func extraDayWeek(_ meters: Double) -> String { "Semana \(kilometers(meters))" }

    static func extraDayReason(_ suggestion: TrainerExtraDay) -> String {
        let minutes = Int((suggestion.currentEasySeconds / 60).rounded())
        return "Com \(kilometers(suggestion.weekMeters)) no plano, as rodagens já têm \(kilometers(suggestion.currentEasyMeters)), cerca de \(minutes) min."
    }

    static func extraDayCurrent(_ runs: Int) -> String { "HOJE · \(runs) CORRIDAS" }
    static func extraDayNext(_ runs: Int) -> String { "COM \(runs) CORRIDAS" }
    static func extraDayEasy(_ meters: Double) -> String { "Rodagem \(kilometers(meters))" }
    static func extraDayLong(_ meters: Double) -> String { "Longão \(kilometers(meters))" }
    static func extraDayKeep(_ runs: Int) -> String { "Manter \(runs)" }
    static func extraDayReview(_ runs: Int) -> String { "Ver com \(runs)" }

    static func warningsCount(_ count: Int) -> String {
        count == 1 ? "1 aviso" : "\(count) avisos"
    }

    static func kilometers(_ meters: Double) -> String {
        meters > 0 ? "\(Int((meters / 1_000).rounded())) km" : noKilometers
    }

    static func summary(peakMeters: Double, meters: Double, quality: Int, alternates: Bool) -> String {
        let requested = Int((peakMeters / 1_000).rounded())
        let suggested = Int((meters / 1_000).rounded())
        let peak = suggested > requested ? "Pico de \(requested) km, dias somam \(suggested) km" : "Pico de \(requested) km"
        if alternates { return "\(peak) · 1 de qualidade, alternando limiar e VO2" }
        return "\(peak) · \(quality) de qualidade"
    }
}
