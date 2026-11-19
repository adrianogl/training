import Foundation

enum RunWeatherBandConstants {
    static let degreeFormat = "%d°"
    static let dewPointFormat = "Orvalho %d °C"
    static let muggy = "abafado"
    static let muggyDewPoint = 18.0
    static let sunny = "sol forte"
    static let separator = " · "
    static let coldTitle = "Frio"
    static let mildTitle = "Clima ameno"
    static let degreeFontSize = 30.0
    static let backgroundOpacity = 0.12
    static let cornerRadius = 14.0
    static let padding = 12.0
    static let percentScale = 100.0
    static let kmhPerMs = 3.6
    static let compass = ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]
    static let compassSector = 45.0
    static let symbol = "thermometer.medium"
    static let headerBottomSpacing = 12.0
    static let captionLabel = "clima"
    static let captionFormat = "%@ mais lento"
    static let captionCostFormat = "+%d\u{00A0}s/\u{2060}km pelo %@"
    static let heatWord = "calor"
    static let coldWord = "frio"
    static let costFormat = ": o %@ custou cerca de %d\u{00A0}s/\u{2060}km. Sem ele, seu pace seria perto de %@/km."
    static let adaptationCostFormat = "Você já fez %d treinos no calor; sem essa adaptação, o custo seria de cerca de %d\u{00A0}s/\u{2060}km."
    static let minimumCostSeconds = 1.0
    static let muggyOpeningFormat = "Dia abafado (orvalho %d °C)"
    static let dewOpeningFormat = "Orvalho %d °C"
    static let sunnySuffix = " e sol forte"
    static let heatCostFormat = ": o calor deixou o pace cerca de %@ mais lento."
    static let coldCostFormat = ": o frio deixou o pace cerca de %@ mais lento."
    static let sentenceEnd = "."
    static let adaptationFormat = "Como você já fez %d treinos no calor, esse efeito foi %d%% menor."
    static let windFormat = "Vento de %d km/h de %@."
    static let windShownKmh = 15.0
}
