import Testing
import TrainingCore
@testable import Insights

@Suite struct ExternalDayKindTests {
    private func workout(_ name: String, meters: Double = 10_000) -> TrainerExternalWorkout {
        TrainerExternalWorkout(day: Day(iso: "2026-11-18")!, name: name, totalMeters: meters, steps: [])
    }

    @Test func readsTheKindFromTheAdvisoryName() {
        #expect(ExternalDayKind.kind(workout("Corrida Limiar Anaeróbio Fracio")) == .threshold)
        #expect(ExternalDayKind.kind(workout("Corrida Intervalado - VO2 Máx.")) == .vo2max)
        #expect(ExternalDayKind.kind(workout("Corrida Longo sáb 15/11")) == .long)
        #expect(ExternalDayKind.kind(workout("Corrida Ritmo de maratona ter 26")) == .threshold)
        #expect(ExternalDayKind.kind(workout("Corrida Corrida fácil seg 16/11")) == .easy)
        #expect(ExternalDayKind.kind(workout("Corrida Regenerativo ter 18/11")) == .easy)
        #expect(ExternalDayKind.kind(workout("Corrida Ritmo de prova 10 Km qua")) == .threshold)
        #expect(ExternalDayKind.kind(workout("Prova LIVE!21K")) == .race)
    }

    @Test func longDistanceCountsAsLongRun() {
        #expect(ExternalDayKind.kind(workout("Corrida", meters: 20_000)) == .long)
    }

    @Test func structureByWeekdayUsesTheWeekOfTheDay() {
        let monday = Day(iso: "2026-11-16")!
        let workouts = [
            TrainerExternalWorkout(day: monday.adding(days: 1), name: "Limiar", totalMeters: 11_000, steps: []),
            TrainerExternalWorkout(day: monday.adding(days: 5), name: "Longo", totalMeters: 22_000, steps: []),
            TrainerExternalWorkout(day: monday.adding(days: 8), name: "Limiar", totalMeters: 11_000, steps: []),
        ]
        #expect(ExternalDayKind.structure(workouts, week: monday) == [2: .threshold, 6: .long])
    }
}
