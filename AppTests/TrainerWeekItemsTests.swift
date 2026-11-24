import Insights
import Testing
import TrainingCore
@testable import trAIning

struct TrainerWeekItemsTests {
    private func planned(_ iso: String) -> TrainerDayRow {
        let day = Day(iso: iso) ?? Day.today()
        return TrainerDayRow(workout: TrainerWorkout(day: day, kind: .easy, title: "Rodagem", totalMeters: 10_000, steps: [], rationale: ""), status: .planned, run: nil, isChanged: false)
    }

    private func done(_ id: Int64, _ iso: String) -> WorkoutRowData {
        WorkoutRowData(
            activityId: id, title: "Corrida", names: ["Corrida"], dayIso: iso, dateText: "", distanceText: nil,
            durationText: nil, paceText: nil, hasPrescription: false, score: nil, kilometers: nil,
            zoneShares: [], weekStart: Day(iso: iso) ?? Day.today()
        )
    }

    private func ids(_ items: [TrainerWeekItem]) -> [String] { items.map(\.id) }

    @Test func doneDayShowsWorkoutCardsInsteadOfPlannedLine() {
        let items = TrainerWeekItems.items(
            rows: [planned("2026-11-23"), planned("2026-11-24")],
            done: [done(1, "2026-11-23"), done(2, "2026-11-23")]
        )
        #expect(ids(items) == ["feito-1", "feito-2", "plano-2026-11-24"])
    }

    @Test func workoutOutsideThePlanAppearsOnItsDay() {
        let items = TrainerWeekItems.items(
            rows: [planned("2026-11-23"), planned("2026-11-25")],
            done: [done(7, "2026-11-24")]
        )
        #expect(ids(items) == ["plano-2026-11-23", "feito-7", "plano-2026-11-25"])
    }

    @Test func weekWithoutWorkoutsKeepsTrainerLines() {
        let items = TrainerWeekItems.items(rows: [planned("2026-11-26")], done: [])
        #expect(ids(items) == ["plano-2026-11-26"])
    }
}
