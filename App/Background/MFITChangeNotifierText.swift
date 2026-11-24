enum MFITChangeNotifierText {
    static let title = "Treino novo no MFIT"
    static let defaultTeacher = "O professor"
    static let watchCurrent = "Já está no relógio."
    static let watchPending = "Falta enviar ao relógio."

    static func body(_ changes: [MFITProgramChange], teacher: String?, weekday: (MFITProgramChange) -> Int?, watch: TrainerChangeWatch) -> String {
        let who = teacher.flatMap { $0.isEmpty ? nil : $0 } ?? defaultTeacher
        let summary: String
        if changes.count == 1, let change = changes.first {
            let day = weekday(change).flatMap { TrainerConstants.weekdayFull.indices.contains($0) ? TrainerConstants.weekdayFull[$0] : nil }
            summary = day.map { "\(who) mudou o treino de \($0): \(change.workout.title)." } ?? "\(who) mudou o treino \(change.workout.title)."
        } else {
            summary = "\(who) mudou \(changes.count) treinos."
        }
        switch watch {
        case .none: return summary
        case .current: return "\(summary) \(watchCurrent)"
        case .pending: return "\(summary) \(watchPending)"
        }
    }
}
