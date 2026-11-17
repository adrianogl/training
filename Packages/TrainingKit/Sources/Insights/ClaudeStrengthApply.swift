public enum ClaudeStrengthApply {
    public static func apply(_ imported: GeneratedStrengthWorkout, session: TrainerStrengthSession, context: StrengthContext) -> GeneratedStrengthWorkout {
        let fallback = StrengthGenerator.workout(for: session, context: context)
        let overriding = fallback.adjustments.contains { adjustment in
            switch adjustment {
            case .raceRest, .raceWeek, .lowReadiness: true
            default: false
            }
        }
        if overriding { return fallback }
        guard !context.pain.isEmpty else { return imported }
        var result = imported
        result.exercises.removeAll { StrengthCatalog.exercise($0.exerciseId)?.loads.isDisjoint(with: context.pain) == false }
        if result.exercises.count != imported.exercises.count {
            result.adjustments.append(.pain(context.pain))
        }
        return result
    }
}
