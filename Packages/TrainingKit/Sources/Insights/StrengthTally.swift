import TrainingCore

public struct StrengthSourceTally: Sendable, Equatable {
    public let source: TrainerStrengthSource
    public let done: Int
    public let planned: Int

    public init(source: TrainerStrengthSource, done: Int, planned: Int) {
        self.source = source
        self.done = done
        self.planned = planned
    }
}

public enum StrengthTally {
    public static func week(start: Day, sessions: [TrainerStrengthSession], doneDays: Set<Day>) -> [StrengthSourceTally] {
        TrainerStrengthSource.allCases.compactMap { source in
            let planned = sessions.filter { $0.source == source }
            guard !planned.isEmpty else { return nil }
            let done = planned.filter { doneDays.contains(start.adding(days: $0.weekday - 1)) }.count
            return StrengthSourceTally(source: source, done: done, planned: planned.count)
        }
    }
}
