import Foundation
import TrainingCore

public enum ClaudeStrengthParser {
    public static func parse(_ text: String) throws -> ClaudeStrengthResponse {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let response = try? JSONDecoder().decode(ClaudeStrengthResponse.self, from: Data(text[start...end].utf8)) else {
            if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
               let probe = try? JSONSerialization.jsonObject(with: Data(text[start...end].utf8)) as? [String: Any],
               let version = probe["versao"] as? Int, version != ClaudeStrengthConstants.version {
                throw ClaudeStrengthParseError.unsupportedVersion(version)
            }
            throw ClaudeStrengthParseError.invalid
        }
        guard response.version == ClaudeStrengthConstants.version else { throw ClaudeStrengthParseError.unsupportedVersion(response.version) }
        return response
    }
}

public enum ClaudeStrengthValidator {
    private typealias C = ClaudeStrengthConstants

    public static func validate(_ response: ClaudeStrengthResponse, context: ClaudeValidationContext) -> [ClaudeDayResult] {
        response.workouts.map { validate($0, context: context) }
    }

    private static func validate(_ entry: ClaudeStrengthDay, context: ClaudeValidationContext) -> ClaudeDayResult {
        var result = ClaudeDayResult(rawDay: entry.day, day: Day(iso: entry.day), why: entry.why, workout: nil, errors: [], warnings: [])
        guard let day = result.day else {
            result.errors.append(.invalidDate)
            return result
        }
        let weekday = day.weekStart.days(until: day) + 1
        let session = context.trainerSessions.first { $0.source == .trainer && $0.weekday == weekday }
        if day <= context.today {
            result.errors.append(.pastDay)
        } else if day < context.first || day > context.last {
            result.errors.append(.outOfPeriod)
        } else if context.mfitWeekdays.contains(weekday) {
            result.errors.append(.mfitDay)
        } else if session == nil {
            result.errors.append(.notTrainerDay)
        }
        let place = entry.place ?? session?.place ?? .gym
        var exercises: [GeneratedExercise] = []
        var catalog: [CatalogExercise] = []
        if entry.exercises.isEmpty { result.errors.append(.noExercises) }
        if entry.exercises.count > C.maxExercises { result.errors.append(.tooManyExercises) }
        for item in entry.exercises {
            guard let exercise = StrengthCatalog.exercise(item.id) else {
                result.errors.append(.unknownExercise(item.id))
                continue
            }
            if !exercise.fits(place) { result.errors.append(.wrongPlace(item.id)) }
            if !exercise.loads.isDisjoint(with: context.pain) { result.errors.append(.painRegion(item.id)) }
            if !doseIsValid(item) { result.errors.append(.doseOutOfRange(item.id)) }
            if let kilograms = item.kilograms, let last = context.lastLoads[item.id], kilograms > last * C.loadJumpShare {
                result.warnings.append(.loadJump(item.id))
            }
            catalog.append(exercise)
            exercises.append(GeneratedExercise(
                exerciseId: exercise.id, name: exercise.name, category: exercise.category, exerciseName: exercise.exerciseName,
                sets: item.sets, reps: item.seconds == nil ? item.reps : nil, seconds: item.seconds, restSeconds: item.rest ?? C.defaultRest,
                weight: item.kilograms, perSide: exercise.unilateral
            ))
        }
        if isHeavyLegs(catalog), [1, 2].contains(where: { context.runKinds[day.adding(days: $0)].map(C.qualityKinds.contains) ?? false }) {
            result.errors.append(.heavyLegsBeforeQuality)
        }
        if let race = context.raceDay, C.raceRestDays.contains(day.days(until: race)) {
            result.errors.append(.nearRace)
        }
        let planned = entry.minutes ?? session?.minutes ?? TrainerStrengthSession.defaultMinutes
        var workout = GeneratedStrengthWorkout(
            weekday: weekday, group: entry.focus ?? session?.group ?? .core, intensity: session?.intensity ?? .moderate,
            minutes: planned, place: place, exercises: exercises, adjustments: []
        )
        let estimated = Int(workout.estimatedMinutes.rounded())
        if abs(Double(estimated - planned)) > C.durationToleranceMinutes {
            result.warnings.append(.durationOff(estimated: estimated, planned: planned))
        }
        workout.minutes = planned
        result.workout = workout
        return result
    }

    private static func doseIsValid(_ item: ClaudeStrengthExercise) -> Bool {
        guard C.sets.contains(item.sets), C.rest.contains(item.rest ?? C.defaultRest) else { return false }
        if let seconds = item.seconds { return C.seconds.contains(seconds) }
        guard let reps = item.reps else { return false }
        return C.reps.contains(reps)
    }

    static func isHeavyLegs(_ exercises: [CatalogExercise]) -> Bool {
        exercises.filter { C.legPatterns.contains($0.pattern) && C.loadedEquipment.contains($0.equipment) }.count >= C.heavyLegExercises
    }
}
