import Insights

enum TrainerChangeNotifierText {
    static let planTitle = "Plano atualizado"
    static let todayTitle = "Treino de hoje mudou"
    static let tomorrowTitle = "Treino de amanhã mudou"
    static let morningPrefix = "Treino de hoje mudou:"
    static let watchCurrent = "O relógio já tem a versão nova."
    static let watchPending = "Falta enviar ao relógio."

    static func title(isToday: Bool) -> String {
        isToday ? todayTitle : tomorrowTitle
    }

    static func body(_ workout: TrainerWorkout, watch: TrainerChangeWatch) -> String {
        let summary = detail(workout).map { "\(heading(workout)): \($0)." } ?? "\(heading(workout))."
        switch watch {
        case .none: return summary
        case .current: return "\(summary) \(watchCurrent)"
        case .pending: return "\(summary) \(watchPending)"
        }
    }

    static func morningSummary(_ workout: TrainerWorkout) -> String {
        detail(workout).map { "\(heading(workout)), \($0)." } ?? "\(heading(workout))."
    }

    static func morningLine(run: String?, summary: String) -> String {
        "\(morningPrefix) \(run ?? summary)"
    }

    private static func heading(_ workout: TrainerWorkout) -> String {
        workout.kind == .off ? TrainerText.restTitle : workout.title
    }

    private static func detail(_ workout: TrainerWorkout) -> String? {
        guard workout.kind != .off else { return nil }
        let main = workout.steps.filter { $0.kind == .work && $0.method != .repetition }
        guard workout.kind == .threshold || workout.kind == .vo2max, !main.isEmpty else {
            let line = TrainerText.dayLine(workout).detail
            return line.isEmpty ? nil : line
        }
        return blocks(main) + recovery(workout.steps)
    }

    private static func blocks(_ steps: [TrainerStep]) -> String {
        var groups: [(count: Int, meters: Double)] = []
        for step in steps {
            if let last = groups.last, last.meters == step.meters {
                groups[groups.count - 1].count += step.repeats
            } else {
                groups.append((step.repeats, step.meters))
            }
        }
        return groups.map { "\($0.count) × \(TrainerText.distance($0.meters))" }.joined(separator: TrainerText.blockSeparator)
    }

    private static func recovery(_ steps: [TrainerStep]) -> String {
        if let rest = steps.compactMap(\.restSeconds).first(where: { $0 > 0 }) {
            return " com descanso parado de \(TrainerText.restClock(rest))"
        }
        guard let step = steps.first(where: { $0.kind == .recovery && $0.meters > 0 }) else { return "" }
        return " com recuperação de \(TrainerText.distance(step.meters))"
    }
}
