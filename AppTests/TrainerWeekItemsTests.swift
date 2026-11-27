import Insights
import Testing
import TrainingCore
@testable import trAIning

struct TrainerWeekItemsTests {
    private func planned(_ iso: String, kind: TrainerDayKind = .easy) -> TrainerDayRow {
        let day = Day(iso: iso) ?? Day.today()
        return TrainerDayRow(workout: TrainerWorkout(day: day, kind: kind, title: "Rodagem", totalMeters: 10_000, steps: [], rationale: ""), status: .planned, run: nil, isChanged: false)
    }

    private func done(_ id: Int64, _ iso: String, isStrength: Bool = false) -> WorkoutRowData {
        var row = WorkoutRowData(
            activityId: id, title: "Corrida", names: ["Corrida"], dayIso: iso, dateText: "", distanceText: nil,
            durationText: nil, paceText: nil, hasPrescription: false, score: nil, kilometers: nil,
            zoneShares: [], weekStart: Day(iso: iso) ?? Day.today()
        )
        row.isStrength = isStrength
        return row
    }

    private func ids(_ items: [TrainerWeekItem]) -> [String] { items.map(\.id) }

    @Test func doneDayJoinsPlannedAndDoneInOneCard() {
        let items = TrainerWeekItems.items(
            rows: [planned("2026-11-23"), planned("2026-11-24")],
            done: [done(1, "2026-11-23"), done(2, "2026-11-23")]
        )
        #expect(ids(items) == ["plano-feito-2026-11-23", "plano-2026-11-24"])
        guard case .plannedDone(let row, let runs) = items.first else {
            Issue.record("primeiro item deveria juntar planejado e feito")
            return
        }
        #expect(row.id == "2026-11-23")
        #expect(runs.map(\.activityId) == [1, 2])
    }

    @Test func workoutOnRestDayShowsOnlyTheDoneCard() {
        let items = TrainerWeekItems.items(
            rows: [planned("2026-11-23", kind: .off)],
            done: [done(3, "2026-11-23")]
        )
        #expect(ids(items) == ["feito-3"])
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

    @Test func strengthOnlyKeepsThePlannedRunWithItsStatus() {
        let items = TrainerWeekItems.items(rows: [planned("2026-11-26")], done: [done(9, "2026-11-26", isStrength: true)])
        #expect(ids(items) == ["plano-2026-11-26", "feito-9"])
    }

    @Test func strengthNextToTheRunStaysOutsideTheJoinedCard() {
        let items = TrainerWeekItems.items(
            rows: [planned("2026-11-26")],
            done: [done(10, "2026-11-26"), done(11, "2026-11-26", isStrength: true)]
        )
        #expect(ids(items) == ["plano-feito-2026-11-26", "feito-11"])
    }
}
