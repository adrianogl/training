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
}
