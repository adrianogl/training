import Foundation

public enum StrengthGenerator {
    private typealias C = StrengthGeneratorConstants

    private struct Plan {
        var group: TrainerStrengthGroup
        var intensity: TrainerStrengthIntensity
        var minutes: Double
        var mobilityOnly: Bool
        var adjustments: [StrengthAdjustment]
        var empty: Bool
    }

    public static func workout(for session: TrainerStrengthSession, context: StrengthContext) -> GeneratedStrengthWorkout {
        let plan = plan(for: session, context: context)
        var workout = GeneratedStrengthWorkout(
            weekday: session.weekday, group: plan.group, intensity: plan.intensity, minutes: Int(plan.minutes.rounded()),
            place: session.place, exercises: [], adjustments: plan.adjustments
        )
        guard !plan.empty else { return workout }
        workout.exercises = select(plan: plan, place: session.place, context: context)
        if !context.pain.isEmpty, !workout.exercises.isEmpty {
            workout.adjustments.append(.pain(context.pain))
        }
        return workout
    }

    public static func alternatives(for exerciseId: String, in workout: GeneratedStrengthWorkout, context: StrengthContext) -> [CatalogExercise] {
        guard let current = StrengthCatalog.exercise(exerciseId) else { return [] }
        let used = Set(workout.exercises.map(\.exerciseId))
        return StrengthCatalog.all
            .filter { $0.pattern == current.pattern && !used.contains($0.id) && $0.fits(workout.place) && $0.loads.isDisjoint(with: context.pain) }
            .prefix(3)
            .map { $0 }
    }

    private static func plan(for session: TrainerStrengthSession, context: StrengthContext) -> Plan {
        var plan = Plan(group: session.group, intensity: session.intensity, minutes: Double(session.minutes), mobilityOnly: false, adjustments: [], empty: false)
        if let days = context.daysToRace, days >= 0, days <= C.raceWeekDays {
            if days <= C.raceRestDays {
                plan.empty = true
                plan.adjustments = [.raceRest]
                return plan
            }
            return Plan(group: .core, intensity: .light, minutes: Double(C.raceWeekMinutes), mobilityOnly: true, adjustments: [.raceWeek], empty: false)
        }
        if !context.keepOriginal, let readiness = context.readiness, readiness < C.lowReadiness {
            return Plan(group: .core, intensity: .light, minutes: Double(C.lowReadinessMinutes), mobilityOnly: true, adjustments: [.lowReadiness(score: readiness)], empty: false)
        }
        if !context.keepOriginal, let kind = context.runKind, C.qualityKinds.contains(kind), C.legGroups.contains(session.group) {
            plan.group = .core
            plan.intensity = .light
            plan.adjustments.append(.qualityDay(original: session.group))
        }
        if context.isRecoveryWeek {
            plan.minutes *= C.recoveryShare
            plan.adjustments.append(.recoveryWeek)
        }
        return plan
    }

    private static func select(plan: Plan, place: StrengthPlace, context: StrengthContext) -> [GeneratedExercise] {
        var pool = StrengthCatalog.all.filter { exercise in
            exercise.focus.contains(plan.group) && exercise.fits(place) && exercise.loads.isDisjoint(with: context.pain)
                && (!plan.mobilityOnly || exercise.isMobility)
        }
        var order = plan.mobilityOnly ? C.mobilityOrder : C.patternOrder[plan.group] ?? []
        if pool.isEmpty {
            pool = StrengthCatalog.all.filter { $0.isMobility && $0.fits(place) && $0.loads.isEmpty }
            order = C.mobilityOrder
        }
        order = order.filter { !context.coveredPatterns.contains($0) } + order.filter { context.coveredPatterns.contains($0) }
        pool.sort { rank($0.equipment) < rank($1.equipment) }

        let target = plan.minutes * 60
        let tolerance = C.toleranceMinutes * 60
        var chosen: [GeneratedExercise] = []
        var used: Set<String> = []
        var total = 0.0
        var progressed = true
        while total < target - tolerance, progressed {
            progressed = false
            for pattern in order where total < target - tolerance {
                for candidate in pool where candidate.pattern == pattern && !used.contains(candidate.id) {
                    let exercise = generated(candidate, plan: plan, context: context, used: used)
                    used.insert(candidate.id)
                    used.insert(exercise.exerciseId)
                    guard total + exercise.estimatedSeconds <= target + tolerance else { continue }
                    chosen.append(exercise)
                    total += exercise.estimatedSeconds
                    progressed = true
                    break
                }
            }
        }
        var extra = 0
        while total < target - tolerance, extra < C.maxExtraSets, !chosen.isEmpty {
            extra += 1
            for index in chosen.indices where total < target - tolerance {
                let perSet = chosen[index].workSeconds + Double(chosen[index].restSeconds)
                guard total + perSet <= target + tolerance else { continue }
                chosen[index].sets += 1
                total += perSet
            }
        }
        return chosen
    }

    private static func generated(_ candidate: CatalogExercise, plan: Plan, context: StrengthContext, used: Set<String>) -> GeneratedExercise {
        var exercise = candidate
        var replaced: String?
        if let swapId = context.swaps[candidate.id], let swap = StrengthCatalog.exercise(swapId), !used.contains(swapId), swap.loads.isDisjoint(with: context.pain) {
            exercise = swap
            replaced = candidate.name
        }
        let prescription = prescription(exercise, intensity: plan.intensity, recovery: plan.adjustments.contains(.recoveryWeek))
        let weight = C.loadedEquipment.contains(exercise.equipment) ? StrengthProgression.next(context.loads[exercise.id]) : nil
        return GeneratedExercise(
            exerciseId: exercise.id, name: exercise.name, category: exercise.category, exerciseName: exercise.exerciseName,
            sets: prescription.sets, reps: prescription.reps, seconds: prescription.seconds, restSeconds: prescription.rest,
            weight: weight, perSide: exercise.unilateral, replacedName: replaced
        )
    }

    private static func prescription(_ exercise: CatalogExercise, intensity: TrainerStrengthIntensity, recovery: Bool) -> StrengthPrescription {
        let base = basePrescription(exercise, intensity: intensity)
        guard recovery else { return base }
        return StrengthPrescription(sets: max(1, Int((Double(base.sets) * C.recoveryShare).rounded())), reps: base.reps, seconds: base.seconds, rest: base.rest)
    }

    private static func basePrescription(_ exercise: CatalogExercise, intensity: TrainerStrengthIntensity) -> StrengthPrescription {
        if exercise.isMobility {
            return exercise.timed ? StrengthPrescription(sets: 2, reps: nil, seconds: 40, rest: 15) : StrengthPrescription(sets: 2, reps: 8, seconds: nil, rest: 15)
        }
        if exercise.pattern == .plyo {
            return StrengthPrescription(sets: 3, reps: 6, seconds: nil, rest: 90)
        }
        if C.coreLikePatterns.contains(exercise.pattern) {
            let sets = intensity == .light ? 2 : 3
            let rest = intensity == .heavy ? 45 : 30
            return exercise.timed
                ? StrengthPrescription(sets: sets, reps: nil, seconds: intensity == .heavy ? 45 : 30, rest: rest)
                : StrengthPrescription(sets: sets, reps: intensity == .heavy ? 12 : 10, seconds: nil, rest: rest)
        }
        if exercise.pattern == .calf {
            switch intensity {
            case .light: return StrengthPrescription(sets: 2, reps: 12, seconds: nil, rest: 45)
            case .moderate: return StrengthPrescription(sets: 3, reps: 12, seconds: nil, rest: 60)
            case .heavy: return StrengthPrescription(sets: 3, reps: 10, seconds: nil, rest: 60)
            }
        }
        if exercise.timed {
            return StrengthPrescription(sets: intensity == .light ? 2 : 3, reps: nil, seconds: 40, rest: 45)
        }
        let main = C.mainPatterns.contains(exercise.pattern) && C.mainEquipment.contains(exercise.equipment)
        switch (intensity, main) {
        case (.light, true): return StrengthPrescription(sets: 2, reps: 12, seconds: nil, rest: 60)
        case (.moderate, true): return StrengthPrescription(sets: 3, reps: 10, seconds: nil, rest: 90)
        case (.heavy, true): return StrengthPrescription(sets: 4, reps: 6, seconds: nil, rest: 150)
        case (.light, false): return StrengthPrescription(sets: 2, reps: 12, seconds: nil, rest: 45)
        case (.moderate, false): return StrengthPrescription(sets: 3, reps: 10, seconds: nil, rest: 60)
        case (.heavy, false): return StrengthPrescription(sets: 3, reps: 8, seconds: nil, rest: 90)
        }
    }

    private static func rank(_ equipment: StrengthEquipment) -> Int {
        C.equipmentPreference.firstIndex(of: equipment) ?? C.equipmentPreference.count
    }
}
