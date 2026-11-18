import Foundation

enum RunWeatherBandConstants {
    static let degreeFormat = "%d°"
    static let dewPointFormat = "Orvalho %d °C"
    static let muggy = "abafado"
    static let muggyDewPoint = 18.0
    static let sunny = "sol forte"
    static let adaptedFormat = "adaptado: %d treinos no calor em 14 dias"
    static let separator = " · "
    static let heatFormat = "Calor deixa o ritmo %@ mais lento"
    static let coldFormat = "Frio deixa o ritmo %@ mais lento"
    static let coldTitle = "Frio"
    static let mildTitle = "Clima ameno"
    static let degreeFontSize = 30.0
    static let backgroundOpacity = 0.12
    static let cornerRadius = 14.0
    static let padding = 12.0
    static let percentScale = 100.0
    static let cardDegreeFontSize = 40.0
    static let paceLabel = "Efeito no ritmo"
    static let heatValueFormat = "+%@ pelo calor"
    static let coldValueFormat = "+%@ pelo frio"
    static let noEffect = "nenhum"
    static let adaptationLabel = "Adaptação (14 dias)"
    static let adaptationValueFormat = "%d treinos · −%d%%"
    static let windLabel = "Vento"
    static let windValueFormat = "%d km/h de %@"
    static let kmhPerMs = 3.6
    static let compass = ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]
    static let compassSector = 45.0
}
