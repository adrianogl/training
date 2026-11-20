public enum StrengthLoadSuggestion {
    private typealias C = StrengthLoadSuggestionConstants

    public static func suggest(for exercise: CatalogExercise, history: [String: StrengthLoadRecord]) -> SuggestedLoad? {
        guard let increment = C.increments[exercise.equipment] else { return nil }
        guard let base = base(for: exercise, history: history) else { return nil }
        var share = C.firstTimeShare
        if base.exercise.equipment == .barbell, C.handheld.contains(exercise.equipment) { share *= C.perHandShare }
        if exercise.unilateral && !base.exercise.unilateral { share *= C.unilateralShare }
        let raw = base.record.weight * share
        let rounded = (raw / increment).rounded(.down) * increment
        guard rounded >= increment else { return nil }
        return SuggestedLoad(weight: rounded, baseId: base.exercise.id, baseWeight: base.record.weight, baseDay: base.record.day)
    }

    private static func base(for exercise: CatalogExercise, history: [String: StrengthLoadRecord]) -> (exercise: CatalogExercise, record: StrengthLoadRecord)? {
        let candidates: [(exercise: CatalogExercise, record: StrengthLoadRecord)] = StrengthCatalog.all.compactMap { other in
            guard other.id != exercise.id, other.pattern == exercise.pattern || other.category == exercise.category, let record = history[other.id] else { return nil }
            guard !(other.unilateral && !exercise.unilateral) else { return nil }
            return (other, record)
        }
        let same = candidates.filter { $0.exercise.equipment == exercise.equipment }
        if let best = latest(same) { return best }
        let paired = candidates.filter { isPair($0.exercise.equipment, exercise.equipment) }
        return latest(paired)
    }

    private static func isPair(_ base: StrengthEquipment, _ target: StrengthEquipment) -> Bool {
        (base == .barbell && C.handheld.contains(target)) || (C.handheld.contains(base) && target == .barbell)
    }

    private static func latest(_ candidates: [(exercise: CatalogExercise, record: StrengthLoadRecord)]) -> (exercise: CatalogExercise, record: StrengthLoadRecord)? {
        candidates.min { lhs, rhs in
            let l = lhs.record.day ?? "", r = rhs.record.day ?? ""
            if l != r { return l > r }
            return lhs.exercise.id < rhs.exercise.id
        }
    }
}
