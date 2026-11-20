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
        var result = imported
        result.exercises = result.exercises.map { suggesting($0, context: context) }
        guard !context.pain.isEmpty else { return result }
        result.exercises.removeAll { StrengthCatalog.exercise($0.exerciseId)?.loads.isDisjoint(with: context.pain) == false }
        if result.exercises.count != imported.exercises.count {
            result.adjustments.append(.pain(context.pain))
        }
        return result
    }

    private static func suggesting(_ exercise: GeneratedExercise, context: StrengthContext) -> GeneratedExercise {
        guard exercise.weight == nil, context.loads[exercise.exerciseId] == nil,
              let catalog = StrengthCatalog.exercise(exercise.exerciseId),
              StrengthGeneratorConstants.loadedEquipment.contains(catalog.equipment),
              let suggestion = StrengthLoadSuggestion.suggest(for: catalog, history: context.loads) else { return exercise }
        var result = exercise
        result.weight = suggestion.weight
        result.suggestedLoad = suggestion
        return result
    }
}
