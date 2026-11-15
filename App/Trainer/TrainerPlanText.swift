import Foundation
import Insights

extension TrainerText {
    static let adjustmentsTitle = "Ajustes do plano"
    static let editPacesButton = "Editar paces e plano"
    static let pastScoreboards = "Semanas anteriores"

    static func weekProgress(index: Int?, total: Int) -> String? {
        guard let index, total > 0 else { return nil }
        return "semana \(index) de \(total)"
    }

    static func adjustmentsSummary(strength: [TrainerStrengthSession], longMode: TrainerLongMode) -> String {
        let strengthPart = strength.isEmpty ? "Força" : "Força \(strength.count)×/semana"
        return [strengthPart, "Longão \(longModeName(longMode).lowercased())", "Paces", askButton].joined(separator: " · ")
    }
}
