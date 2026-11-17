import Foundation
import Insights
import TrainingCore

extension TrainerModel {
    func trainerSessions(on day: Day) -> [TrainerStrengthSession] {
        guard let plan else { return [] }
        let weekday = day.weekStart.days(until: day) + 1
        return plan.strength.filter { $0.source == .trainer && $0.weekday == weekday }
    }

    func strengthWorkout(sessionId: UUID, day: Day) -> GeneratedStrengthWorkout? {
        guard let plan, let session = plan.strength.first(where: { $0.id == sessionId }) else { return nil }
        let context = TrainerStrengthContextBuilder.context(
            day: day, plan: plan, readiness: day == currentDay ? history.readiness[day] : nil,
            prefs: TrainerStrengthPrefsStore().load(), cache: StrengthProgramStore().load(), schedule: StrengthSchedule()
        )
        return StrengthGenerator.workout(for: session, context: context)
    }

    func strengthAlternatives(exerciseId: String, in workout: GeneratedStrengthWorkout) -> [CatalogExercise] {
        StrengthGenerator.alternatives(for: exerciseId, in: workout, context: StrengthContext(pain: TrainerStrengthPrefsStore().load().pain))
    }

    func strengthTally(weekStart: Day) -> [StrengthSourceTally] {
        guard let plan else { return [] }
        return StrengthTally.week(start: weekStart, sessions: plan.strength, doneDays: Set(history.strength.map(\.day)))
    }

    func suggestedStrength() -> [TrainerStrengthSession] {
        guard let plan else { return [] }
        let structure = Dictionary(plan.workouts.filter { $0.day.weekStart == currentDay.weekStart }.map { ($0.day.weekStart.days(until: $0.day) + 1, $0.kind) }, uniquingKeysWith: { first, _ in first })
        return StrengthSuggestion.suggest(plan.strength, structure: structure)
    }
}
