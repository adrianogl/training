import SwiftUI

enum StrengthLiveWidgetConstants {
    static let lime = Color(red: 0.78, green: 0.94, blue: 0.35)
    static let blue = Color(red: 0.50, green: 0.70, blue: 1.0)
    static let lilac = Color(red: 0.71, green: 0.61, blue: 1.0)
    static let heart = Color(red: 0.90, green: 0.33, blue: 0.29)
    static let yellow = Color(red: 1.0, green: 0.76, blue: 0.30)
    static let dim = Color(red: 0.54, green: 0.58, blue: 0.62)
    static let soft = Color(red: 0.79, green: 0.80, blue: 0.82)
    static let text = Color(red: 0.91, green: 0.93, blue: 0.94)
    static let background = Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.80)
    static let deepLink = URL(string: "training://treinador/forca")!

    static let doingLabel = "FAZENDO · SÉRIE %d DE %d"
    static let restLabel = "DESCANSO"
    static let restOverLabel = "HORA DA SÉRIE %d DE %d"
    static let pausedLabel = "PAUSADO"
    static let finishedLabel = "TREINO CONCLUÍDO"
    static let lastPrefix = "Última vez: "
    static let donePrefix = "Feita: "
    static let nextPrefix = "Próxima: "
    static let nextSuffix = " · série %d"
    static let overPrefix = "Descanso "
    static let plus = "+"
    static let overSuffix = " além do previsto"
    static let restOfPrefix = "de "
    static let kilograms = "kg"
    static let islandRest = "Descanso"
    static let islandRestOver = "Hora da série %d"
    static let islandPaused = "Pausado"
    static let heartSymbol = "heart.fill"
    static let iconName = "LiveIcon"
    static let barHeight: CGFloat = 6
    static let barSpacing: CGFloat = 4
    static let iconSize: CGFloat = 18
    static let iconRadius: CGFloat = 5
    static let cardPadding: CGFloat = 16
    static let rowSpacing: CGFloat = 10
}
