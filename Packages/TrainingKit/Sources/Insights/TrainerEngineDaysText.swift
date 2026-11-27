import Foundation
import TrainingCore

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

    static func minimumVolumeWarning(runs: Int, minimum: Double, peak: Double) -> String {
        "Com \(runs) corridas e rodagens de pelo menos 40 min, a semana passa de \(kilometers(minimum)), acima do pico de \(kilometers(peak)). Use \(runs - 1) corridas ou suba o pico."
    }

    static func volumeWarning(runs: Int, possible: Double, peak: Double, nextPossible: Double?) -> String {
        let base = "Com \(runs) corridas, o pico possível é \(kilometers(possible)), não \(kilometers(peak))."
        guard let nextPossible else { return base }
        if nextPossible >= peak { return "\(base) Com \(runs + 1) corridas, os \(kilometers(peak)) cabem." }
        return "\(base) Com \(runs + 1) corridas, o pico possível sobe para \(kilometers(nextPossible))."
    }
}

extension TrainerEngineText {
    static func swapEveOfLong(_ conflict: TrainerSwapConflict, alternative: Day?, longMove: Day?) -> TrainerSwapWarning {
        let name = titleName(kind: conflict.quality.kind, method: conflict.quality.method, variant: conflict.quality.variant)
        let lowered = name == dayKindName(.vo2max) ? name : name.lowercased()
        let article = conflict.quality.variant == .hills ? "as" : "o"
        let longDay = weekdayName(conflict.long.day)
        var text = "\(longDay.prefix(1).uppercased() + longDay.dropFirst()) tem longão de \(kilometers(conflict.long.totalMeters)). "
            + "Com \(article) \(lowered) \(weekdayPreposition(conflict.quality.day)) \(weekdayName(conflict.quality.day)), você chega ao longão sem recuperar."
        switch (alternative, longMove) {
        case let (alternative?, longMove?):
            text += " Prefira \(weekdayName(alternative)), ou passe o longão para \(weekdayName(longMove)) depois de trocar."
        case let (alternative?, nil):
            text += " Prefira \(weekdayName(alternative))."
        case let (nil, longMove?):
            text += " Passe o longão para \(weekdayName(longMove)) depois de trocar."
        case (nil, nil):
            break
        }
        return TrainerSwapWarning(title: "\(name) na véspera do longão", text: text)
    }

    static func weekdayPreposition(_ day: Day) -> String {
        day.weekStart.days(until: day) >= TrainerEngineConstants.weekendStartIndex ? "no" : "na"
    }
}
