import SwiftUI

enum WidgetConstants {
    static let displayName = "Hoje"
    static let description = "Prontidão, treino do dia e dias para a prova."
    static let readinessLabel = "Prontidão"
    static let todayLabel = "Hoje"
    static let rest = "Descanso"
    static let strengthPrefix = "Força · "
    static let lime = Color(red: 0.78, green: 0.94, blue: 0.35)
    static let gold = Color(red: 0.95, green: 0.79, blue: 0.30)
    static let amber = Color(red: 0.95, green: 0.69, blue: 0.29)
    static let violet = Color(red: 0.71, green: 0.61, blue: 1.0)
    static let background = Color(red: 0.07, green: 0.09, blue: 0.11)
    static let dim = Color(red: 0.54, green: 0.58, blue: 0.62)
    static let refreshHours = 1

    static func raceText(_ snapshot: WidgetSnapshot) -> String? {
        guard let name = snapshot.raceName, let days = snapshot.raceDays else { return nil }
        return days == 0 ? "Hoje · \(name)" : "\(days) \(days == 1 ? "dia" : "dias") · \(name)"
    }

    static func scoreColor(_ score: Int) -> Color {
        score >= 70 ? lime : score >= 45 ? gold : amber
    }
}
