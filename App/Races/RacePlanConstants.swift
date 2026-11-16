import SwiftUI

enum RacePlanConstants {
    static let cacheFileName = "pacepro.json"
    static let choiceDefaultsKey = "paceProChoice"
    static let title = "Plano × feito"
    static let paceProLabel = "Pace Pro"
    static let appStrategyLabel = "estratégia do app"
    static let ofPacePro = "do Pace Pro"
    static let ofAppStrategy = "da estratégia do app"
    static let yourTime = "seu tempo"
    static let eveLabel = "previsão do app"
    static let planPrefix = "Plano: "
    static let change = "trocar"
    static let pickerTitle = "Plano do Pace Pro"
    static let useAppStrategy = "Estratégia do app"
    static let cumulativeTitle = "Diferença acumulada por km"
    static let tableTitle = "Km a km"
    static let columns = ["km", "plano", "feito", "no km", "acum."]
    static let behindLabel = "atrás do plano"
    static let aheadLabel = "à frente"
    static let chartHeight: CGFloat = 130
    static let evenTolerance = 2.0
    static let strayTolerance = 1.0
    static let finishTolerance = 3.0
    static let waterAllowance = 3.0
    static let waterTag = "água"
    static let waterColor = Color(light: 0x2F6FD6, dark: 0x7FB2FF)
}
