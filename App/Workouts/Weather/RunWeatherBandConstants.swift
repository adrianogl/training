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
    static let captionFormat = "clima +%@"
    static let summaryAdaptedFormat = "adaptado: %d treinos no calor (−%d%%)"
    static let summaryWindFormat = "vento %d km/h de %@"
}
