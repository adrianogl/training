import Insights

enum StrengthPlanEndText {
    static func title(_ objective: StrengthObjective) -> String {
        "Plano de \(name(objective)) terminou"
    }

    static func body(done: Int, planned: Int) -> String {
        "Foram \(done) de \(planned) treinos. Toque para montar o próximo."
    }

    private static func name(_ objective: StrengthObjective) -> String {
        switch objective {
        case .mobility: "mobilidade para corrida"
        case .strength: "força"
        case .prevention: "prevenção"
        case .performance: "performance na corrida"
        case .maintenance: "manutenção"
        }
    }
}
