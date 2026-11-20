import Foundation

enum WorkoutCoachFactsConstants {
    static let scoreFormat = "Nota do treino: %d de 100 (%@)."
    static let scorePartFormat = "%@ %d de %d"
    static let scorePartSeparator = ", "
    static let effectFormat = "Efeito do treino segundo o relógio: %@."
    static let effectAerobicFormat = "aeróbico %@ (%@)"
    static let effectAnaerobicFormat = "anaeróbico %@ (%@)"
    static let effectHighZonesFormat = "%@ em Z4 e Z5"
    static let effectSeparator = ", "
    static let loadFormat = "Carga do treino %@; comparada com as corridas dos últimos 90 dias: %@."
    static let similarFormat = "Contra os treinos parecidos: %@"
    static let goalFormat = "Meta %@ (%@): %@"
    static let planFormat = "Planejado × feito: %d de %d itens cumpridos (%@)."
    static let planItemFormat = "%@ planejado %@, feito %@"
    static let planSeparator = "; "
    static let invisibleSpacing = ["\u{2060}": "", "\u{00A0}": " "]
    static let weekFormat = "Semana do treino: %@ km corridos até este treino."
    static let weekGoalFormat = "Semana do treino: %@ km corridos até este treino, com meta de %d km na semana."
    static let hardFormat = "Último treino forte antes deste: %d dias antes."
    static let hardOneFormat = "Último treino forte antes deste: no dia anterior."
    static let hardSameDayFormat = "Houve outro treino forte no mesmo dia."
    static let conditionFormat = "Condição de performance no início do treino, segundo o relógio: %@."
    static let readinessFormat = "Prontidão do dia do treino: %d de 100."
}
