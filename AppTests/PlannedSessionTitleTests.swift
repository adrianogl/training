import Insights
import Testing
import TrainingCore
@testable import trAIning

struct PlannedSessionTitleTests {
    private let day = Day(year: 2026, month: 11, day: 19)

    private func workout(_ kind: TrainerDayKind, _ title: String, _ meters: Double, variant: TrainerVariant? = nil) -> TrainerWorkout {
        TrainerWorkout(day: day, kind: kind, title: title, totalMeters: meters, steps: [], rationale: "", variant: variant)
    }

    @Test func trainerSessionsShowOnlyTheKind() {
        let cases: [(TrainerWorkout, String)] = [
            (workout(.vo2max, "VO2 máx pirâmide 2 × 1,5 km + 2 × 1 km", 9_000), "VO2 máx"),
            (workout(.threshold, "Limiar progressivo 3 × 2 km", 9_000, variant: .progressiveThreshold), "Limiar"),
            (workout(.long, "Longão 19 km com 3 × 3 km no ritmo da meia", 19_000, variant: .racePaceLong), "Longão"),
            (workout(.easy, "Média-longa 14 km", 14_000, variant: .mediumLong), "Média-longa"),
        ]
        for (trainer, expected) in cases {
            #expect(PlannedSessions.merge(garmin: [], trainer: [trainer]).first?.title == expected)
        }
    }

    @Test func recoveryLineAddsTheDistanceToTheShortTitle() {
        let session = PlannedSessions.merge(garmin: [], trainer: [workout(.vo2max, "VO2 máx pirâmide 2 × 1,5 km + 2 × 1 km", 9_000)])[0]
        let next = RecoveryNext(title: session.title, kind: session.kind, kilometers: session.kilometers, start: .now, hoursFromReady: 0, status: .recovered)
        #expect(RecoveryText.name(next) == "VO2 máx 9 km")
    }
}
