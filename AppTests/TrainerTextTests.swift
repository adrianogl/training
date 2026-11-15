import Foundation
import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerTextTests {
    @Test func formatsPaceRange() {
        #expect(TrainerText.paceRange(low: 254, high: 260) == "4:14–4:20/km")
        #expect(TrainerText.paceRange(low: 260, high: 254) == "4:14–4:20/km")
        #expect(TrainerText.paceRange(low: 254, high: 254.4) == "4:14/km")
        #expect(TrainerText.paceRange(low: 320, high: nil) == "5:20/km")
        #expect(TrainerText.paceRange(low: nil, high: nil) == nil)
    }

    @Test func formatsDistance() {
        #expect(TrainerText.distance(2_000) == "2 km")
        #expect(TrainerText.distance(400) == "400 m")
        #expect(TrainerText.distance(11_800) == "11,8 km")
        #expect(TrainerText.distance(21_097.5) == "21,1 km")
        #expect(TrainerText.distance(10_000) == "10 km")
    }

    @Test func buildsStepRowsByDistance() {
        let workout = TrainerStoreTests.plan().workouts[0]
        let rows = TrainerText.stepRows(workout)
        #expect(rows.map(\.title) == ["Aquecimento", "3× Limiar", "Recuperação"])
        #expect(rows.map(\.detail) == ["3 km", "2 km · 4:14–4:20/km", "400 m · trote"])
    }

    @Test func interleavesRepeatsInShape() {
        let bars = TrainerText.shapeBars(TrainerStoreTests.plan().workouts[0].steps)
        #expect(bars.map(\.kind) == [.warmup, .work, .recovery, .work, .recovery, .work])
    }

    @Test func showsRestStepAsStandingByTime() {
        var workout = TrainerStoreTests.plan().workouts[0]
        workout.steps[2] = TrainerStep(kind: .recovery, repeats: 2, meters: 0, restSeconds: 90)
        let rows = TrainerText.stepRows(workout)
        #expect(rows[2].title == "Descanso parado")
        #expect(rows[2].detail == "1:30")
        let bars = TrainerText.shapeBars(workout.steps)
        #expect(bars.filter(\.isRest).count == 2)
        #expect(bars.filter(\.isRest).allSatisfy { $0.kind == .recovery && $0.meters == 0 })
    }

    @Test func formatsDatesAndWeeks() {
        let day = Day(iso: "2026-11-17")!
        #expect(TrainerText.weekdayShort(day) == "ter")
        #expect(TrainerText.longDate(day) == "terça, 17 de novembro")
        #expect(TrainerText.weekTitle(index: 2, start: Day(iso: "2026-11-16")!) == "Semana 2 · 16 a 22 nov")
    }

    @Test func labelsStatus() {
        let workout = TrainerStoreTests.plan().workouts[0]
        let run = TrainerRun(activityId: 1, day: workout.day, meters: 9_000, seconds: 2_700, kind: .tempo)
        #expect(TrainerText.status(for: TrainerDayRow(workout: workout, status: .partial, run: run, isChanged: false))?.text == "9 km")
        #expect(TrainerText.status(for: TrainerDayRow(workout: workout, status: .planned, run: nil, isChanged: true))?.text == "mudou")
        #expect(TrainerText.status(for: TrainerDayRow(workout: workout, status: .planned, run: nil, isChanged: false)) == nil)
        let onTarget = TrainerRun(activityId: 2, day: workout.day, meters: 11_800, seconds: 3_400, kind: .tempo, activeOnTarget: 3, activeTotal: 3)
        #expect(TrainerText.status(for: TrainerDayRow(workout: workout, status: .done, run: onTarget, isChanged: false))?.text == "no alvo")
    }
}
