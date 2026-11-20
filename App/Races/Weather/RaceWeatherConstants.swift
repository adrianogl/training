import Foundation

enum RaceWeatherConstants {
    static let forecastDaysAhead = 16
    static let typicalYears = 5
    static let timezone = "auto"
    static let forecastTTL: TimeInterval = 3 * 3600
    static let typicalTTL: TimeInterval = 24 * 3600
    static let secondsPerMinute = 60.0
    static let minutesPerHour = 60
    static let timeSeparator: Character = ":"

    static let forecastLabel = "previsão do tempo"
    static let typicalLabel = "média de 5 anos"
    static let forecastLeadFormat = "No clima previsto: %@"
    static let typicalLeadFormat = "No clima típico: %@"
    static let hoursFormat = "%dh–%dh"
    static let dewPointFormat = "Orvalho %d °C"
    static let paceFormat = "ritmo +%@"
    static let separator = " · "
    static let goalAboveFormat = "Meta %@: %@ acima no clima %@."
    static let goalBelowFormat = "Meta %@: %@ abaixo no clima %@."
    static let forecastWord = "previsto"
    static let typicalWord = "típico"
    static let listFormat = "%d °C · %@"
    static let strategySuffixFormat = " · clima previsto %@"
    static let costFormat = "+%@ pelo %@"
    static let heatWord = "calor"
    static let coldWord = "frio"
    static let neutralCaption = "clima sem efeito no tempo"
}
