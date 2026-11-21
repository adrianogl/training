import Foundation
import Insights
import TrainingCore

extension TrainerModel {
    var legacyStrengthSessions: [TrainerStrengthSession] { plan?.strength ?? standaloneStrength }

    var strengthSessions: [TrainerStrengthSession] {
        legacyStrengthSessions.filter { $0.source == .mfit } + (strengthPlan?.sessions.filter { $0.source == .trainer } ?? [])
    }

    func isStrengthPlanActive(on day: Day) -> Bool {
        strengthPlan?.isActive(on: day) ?? false
    }

    func trainerSessions(on day: Day) -> [TrainerStrengthSession] {
        if let override = claudeOverride(on: day) { return [override] }
        guard isStrengthPlanActive(on: day) else { return [] }
        let weekday = day.weekStart.days(until: day) + 1
        return strengthSessions.filter { $0.source == .trainer && $0.weekday == weekday }
    }

    func claudeWorkout(on day: Day) -> ClaudeStoredWorkout? {
        guard let stored = claudeStore.workout(on: day) else { return nil }
        guard let planId = stored.planId else { return stored }
        guard let strengthPlan, strengthPlan.id == planId, strengthPlan.isActive(on: day) else { return nil }
        return stored
    }

    func isFreeClaudeDay(_ day: Day) -> Bool {
        claudeWorkout(on: day).map { $0.planId == nil } ?? false
    }

    static func strengthHistory(_ history: TrainerHistory, for session: TrainerStrengthSession, plan: StrengthPlan?) -> TrainerHistory {
        guard session.source == .trainer else { return history }
        var scoped = history
        scoped.strength = history.strength.filter { plan?.isActive(on: $0.day) ?? false }
        return scoped
    }

    func claudeOverride(on day: Day) -> TrainerStrengthSession? {
        guard let stored = claudeWorkout(on: day), stored.overridesMFIT else { return nil }
        let workout = stored.workout
        let id = UUID(uuidString: ClaudeConstants.overrideIdPrefix + day.iso.replacingOccurrences(of: "-", with: "")) ?? UUID()
        return TrainerStrengthSession(
            id: id, weekday: workout.weekday, group: workout.group,
            legLoad: StrengthSessions.legLoad(group: workout.group, intensity: workout.intensity), name: TrainerStrengthText.focusName(workout.group),
            source: .trainer, intensity: workout.intensity, minutes: workout.minutes, place: workout.place
        )
    }

    func strengthDone(on day: Day) -> Bool {
        history.strength.contains { $0.day == day }
    }

    func replacesMFIT(on day: Day) -> Bool {
        claudeOverride(on: day) != nil
    }

    func strengthWorkout(sessionId: UUID, day: Day) -> GeneratedStrengthWorkout? {
        guard let session = strengthSessions.first(where: { $0.id == sessionId }) ?? claudeOverride(on: day).flatMap({ $0.id == sessionId ? $0 : nil }) else { return nil }
        var context = TrainerStrengthContextBuilder.context(
            day: day, plan: plan, externalKind: externalWorkouts.first { $0.day == day }.map(ExternalDayKind.kind),
            readiness: day == currentDay ? history.readiness[day] : nil,
            prefs: TrainerStrengthPrefsStore().load(), cache: StrengthProgramStore().load(), schedule: StrengthSchedule()
        )
        if session.source == .trainer, let active = strengthPlan, active.isActive(on: day) {
            context.objective = active.objective
        }
        if let stored = claudeWorkout(on: day), session.source == .trainer {
            return ClaudeStrengthApply.apply(stored.workout, session: session, context: context)
        }
        return StrengthGenerator.workout(for: session, context: context)
    }

    func strengthAlternatives(exerciseId: String, in workout: GeneratedStrengthWorkout, day: Day) -> [CatalogExercise] {
        let prefs = TrainerStrengthPrefsStore().load()
        let context = StrengthContext(pain: prefs.pain, block: StrengthGenerator.block(for: day), homeEquipment: prefs.effectiveHomeEquipment)
        return StrengthGenerator.alternatives(for: exerciseId, in: workout, context: context)
    }

    func strengthTally(weekStart: Day) -> [StrengthSourceTally] {
        StrengthTally.week(start: weekStart, sessions: strengthSessions, doneDays: Set(history.strength.map(\.day)))
    }

    func suggestedStrength() -> [TrainerStrengthSession] {
        let week = currentDay.weekStart
        let structure = plan.map { plan in
            Dictionary(plan.workouts.filter { $0.day.weekStart == week }.map { ($0.day.weekStart.days(until: $0.day) + 1, $0.kind) }, uniquingKeysWith: { first, _ in first })
        } ?? ExternalDayKind.structure(externalWorkouts, week: week)
        return StrengthSuggestion.suggest(strengthSessions, structure: structure)
    }
}
