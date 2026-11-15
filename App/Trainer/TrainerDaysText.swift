import Foundation

enum TrainerDaysText {
    static let runsTitle = "Corridas por semana"
    static let optionalTitle = "Treino opcional"
    static let optionalHint = "Conta no volume da semana."
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

    static func warningsCount(_ count: Int) -> String {
        count == 1 ? "1 aviso" : "\(count) avisos"
    }

    static func kilometers(_ meters: Double) -> String {
        meters > 0 ? "\(Int((meters / 1_000).rounded())) km" : noKilometers
    }

    static func summary(meters: Double, quality: Int, alternates: Bool) -> String {
        let peak = "Pico de \(Int((meters / 1_000).rounded())) km"
        if alternates { return "\(peak) · 1 de qualidade, alternando limiar e VO2" }
        return "\(peak) · \(quality) de qualidade"
    }
}
