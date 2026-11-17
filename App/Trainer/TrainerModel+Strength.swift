import Foundation
import Insights
import TrainingCore

extension TrainerModel {
    var strengthSessions: [TrainerStrengthSession] { plan?.strength ?? standaloneStrength }

    func trainerSessions(on day: Day) -> [TrainerStrengthSession] {
        let weekday = day.weekStart.days(until: day) + 1
        return strengthSessions.filter { $0.source == .trainer && $0.weekday == weekday }
    }

    func strengthWorkout(sessionId: UUID, day: Day) -> GeneratedStrengthWorkout? {
        guard let session = strengthSessions.first(where: { $0.id == sessionId }) else { return nil }
        let context = TrainerStrengthContextBuilder.context(
            day: day, plan: plan, externalKind: externalWorkouts.first { $0.day == day }.map(ExternalDayKind.kind),
            readiness: day == currentDay ? history.readiness[day] : nil,
            prefs: TrainerStrengthPrefsStore().load(), cache: StrengthProgramStore().load(), schedule: StrengthSchedule()
        )
        return StrengthGenerator.workout(for: session, context: context)
    }

    func strengthAlternatives(exerciseId: String, in workout: GeneratedStrengthWorkout) -> [CatalogExercise] {
        StrengthGenerator.alternatives(for: exerciseId, in: workout, context: StrengthContext(pain: TrainerStrengthPrefsStore().load().pain))
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
