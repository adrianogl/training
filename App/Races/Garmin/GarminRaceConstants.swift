import Foundation

enum GarminRaceConstants {
    static let defaultsKey = "garminRaceLinks"
    static let distanceTolerance = 0.1
    static let standardTolerance = 0.02
    static let cacheTTL: TimeInterval = 3600
    static let suggestionTitleOne = "1 prova no seu Garmin"
    static let suggestionTitleFormat = "%d provas no seu Garmin"
    static let source = "calendário do Garmin"
    static let startFormat = "largada %@"
    static let course = "percurso do Garmin"
    static let noCourse = "Sem percurso: informe a cidade para ter a previsão no clima do dia."
    static let add = "Adicionar"
    static let ignore = "Ignorar"
    static let changesTitle = "Mudou no Garmin"
    static let apply = "Atualizar"
    static let keep = "Manter"
    static let changeFormat = "%@ %@ → %@"
    static let dayLabel = "data"
    static let startLabel = "largada"
    static let distanceLabel = "distância"
    static let noValue = "—"
    static let separator = " · "
    static let metersPerKm = 1_000.0
    static let locale = "pt_BR"
    static let weekdayFormat = "EEE dd/MM"
}
