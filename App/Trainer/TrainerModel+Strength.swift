import Foundation
import Insights
import TrainingCore

extension TrainerModel {
    var strengthSessions: [TrainerStrengthSession] { plan?.strength ?? standaloneStrength }

    func trainerSessions(on day: Day) -> [TrainerStrengthSession] {
        if let override = claudeOverride(on: day) { return [override] }
        let weekday = day.weekStart.days(until: day) + 1
        return strengthSessions.filter { $0.source == .trainer && $0.weekday == weekday }
    }

    func claudeOverride(on day: Day) -> TrainerStrengthSession? {
        guard let stored = ClaudeStrengthStore().workout(on: day), stored.overridesMFIT else { return nil }
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
        let context = TrainerStrengthContextBuilder.context(
            day: day, plan: plan, externalKind: externalWorkouts.first { $0.day == day }.map(ExternalDayKind.kind),
            readiness: day == currentDay ? history.readiness[day] : nil,
            prefs: TrainerStrengthPrefsStore().load(), cache: StrengthProgramStore().load(), schedule: StrengthSchedule()
        )
        if let stored = ClaudeStrengthStore().workout(on: day), session.source == .trainer {
            return ClaudeStrengthApply.apply(stored.workout, session: session, context: context)
        }
        return StrengthGenerator.workout(for: session, context: context)
    }

    func strengthAlternatives(exerciseId: String, in workout: GeneratedStrengthWorkout, day: Day) -> [CatalogExercise] {
        let context = StrengthContext(pain: TrainerStrengthPrefsStore().load().pain, block: StrengthGenerator.block(for: day))
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
