import Foundation

extension TrainerEngineText {
    static func dayKindName(_ kind: TrainerDayKind) -> String {
        switch kind {
        case .easy: "Rodagem"
        case .threshold: "Limiar"
        case .vo2max: "VO2"
        case .optionalEasy: "Opcional"
        case .long: "Longão"
        case .off: "Off"
        case .race: "Prova"
        }
    }

    static func eveOfLongWarning(_ kind: TrainerDayKind) -> String {
        "\(dayKindName(kind)) na véspera do longão: o longão cai com as pernas cansadas."
    }

    static func afterLongWarning(_ kind: TrainerDayKind) -> String {
        "\(dayKindName(kind)) no dia seguinte ao longão: falta um dia leve ou off para recuperar."
    }

    static func strongInARowWarning(_ first: TrainerDayKind, _ second: TrainerDayKind) -> String {
        "\(dayKindName(first)) e \(dayKindName(second)) em dias seguidos: deixe um dia leve ou off entre os dois."
    }

    static func afterLegStrengthWarning(_ kind: TrainerDayKind, weekday: Int) -> String {
        "\(dayKindName(kind)) no dia seguinte à força de pernas de \(weekdayNames[weekday - 1])."
    }

    static let noRestWarning = "A semana não tem dia off: nenhum dia de descanso."

    static func volumeWarning(runs: Int, possible: Double, peak: Double, nextPossible: Double?) -> String {
        let base = "Com \(runs) corridas, o pico possível é \(kilometers(possible)), não \(kilometers(peak))."
        guard let nextPossible else { return base }
        if nextPossible >= peak { return "\(base) Com \(runs + 1) corridas, os \(kilometers(peak)) cabem." }
        return "\(base) Com \(runs + 1) corridas, o pico possível sobe para \(kilometers(nextPossible))."
    }
}
