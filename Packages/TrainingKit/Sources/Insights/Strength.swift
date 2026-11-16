import TrainingCore

public enum StrengthMuscles {
    private typealias C = StrengthConstants

    public static func sets(_ entries: [(category: String?, sets: Int)]) -> [MuscleGroup: Double] {
        var total: [MuscleGroup: Double] = [:]
        for entry in entries {
            guard let category = entry.category else { continue }
            for muscle in C.primary[category] ?? [] { total[muscle, default: 0] += Double(entry.sets) }
            for muscle in C.secondary[category] ?? [] { total[muscle, default: 0] += Double(entry.sets) * C.secondaryWeight }
        }
        return total
    }

    public static func level(_ sets: Double, scale: StrengthScale) -> Int {
        guard sets > 0 else { return 0 }
        let steps = scale == .session ? C.sessionLevels : C.weekLevels
        return 1 + steps.filter { sets >= $0 }.count
    }

    public static func upperShare(_ entries: [(category: String?, sets: Int)]) -> Double {
        let total = entries.reduce(0) { $0 + $1.sets }
        guard total > 0 else { return 0 }
        let upper = entries.filter { entry in
            entry.category.map { !Set(C.primary[$0] ?? []).isDisjoint(with: C.upperMuscles) } ?? false
        }.reduce(0) { $0 + $1.sets }
        return Double(upper) / Double(total)
    }

    public static func legSets(_ entries: [(category: String?, sets: Int)]) -> Int {
        entries.filter { entry in
            entry.category.map { !Set(C.primary[$0] ?? []).isDisjoint(with: C.legMuscles) } ?? false
        }.reduce(0) { $0 + $1.sets }
    }

    public static func isLegDay(_ entries: [(category: String?, sets: Int)]) -> Bool {
        let total = entries.reduce(0) { $0 + $1.sets }
        guard total > 0 else { return false }
        let legs = entries.filter { entry in
            entry.category.map { !Set(C.primary[$0] ?? []).isDisjoint(with: C.legMuscles) } ?? false
        }.reduce(0) { $0 + $1.sets }
        return Double(legs) / Double(total) >= C.legDayShare
    }
}

public enum StrengthHistory {
    public static func weeklyCounts(_ days: [Day], weeks: Int, today: Day) -> [Int] {
        let currentWeek = today.weekStart
        return (0..<weeks).reversed().map { back in
            let start = currentWeek.adding(days: -7 * back)
            let end = start.adding(days: 6)
            return days.filter { start <= $0 && $0 <= end }.count
        }
    }

    public static func average(_ counts: some Collection<Int>) -> Double? {
        guard !counts.isEmpty else { return nil }
        return Double(counts.reduce(0, +)) / Double(counts.count)
    }
}

public enum StrengthWeek {
    public static func legWarnings(_ days: [StrengthWeekDay]) -> [String] {
        days.enumerated().compactMap { index, day in
            guard index > 0, let run = day.run, StrengthConstants.runsAfterLegs.contains(run), days[index - 1].legs else { return nil }
            return TrainerEngineText.afterLegStrengthWarning(run, weekday: index)
        }
    }
}
