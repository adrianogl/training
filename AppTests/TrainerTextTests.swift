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

    @Test func explainsTheVolumeSuggestionAndTheExcludedWeeks() {
        let light = Day(year: 2026, month: 11, day: 16)
        let low = Day(year: 2026, month: 10, day: 26)
        let base = TrainerNormalVolume(meters: 55_000, excluded: [TrainerExcludedWeek(start: light, reason: .light)], fromNormalWeeks: true)
        #expect(TrainerText.normalAverage(base) == "Sua média das semanas normais: 55 km. Ficou de fora a semana de 16 nov (semana leve).")
        let two = TrainerNormalVolume(
            meters: 55_000, excluded: [TrainerExcludedWeek(start: low, reason: .low), TrainerExcludedWeek(start: light, reason: .light)], fromNormalWeeks: true
        )
        #expect(TrainerText.normalAverage(two) == "Sua média das semanas normais: 55 km. Ficaram de fora as semanas de 26 out (abaixo do normal) e 16 nov (semana leve).")
        #expect(TrainerText.normalAverage(TrainerNormalVolume(meters: 49_000, excluded: [], fromNormalWeeks: false)) == "Sua média das últimas 4 semanas: 49 km")

        let growth = TrainerVolumeSuggestion(startMeters: 55_000, peakMeters: 68_000, limit: .growth, base: base)
        #expect(TrainerText.volumeSuggestionTitle(start: 55_000, peak: 68_000) == "Sugerido: 55 → 68 km")
        #expect(TrainerText.volumeSuggestionReason(growth) == "Começa na sua média das semanas normais e sobe 25% no ciclo.")
        let comfortable = TrainerVolumeSuggestion(startMeters: 55_000, peakMeters: 62_000, limit: .comfortable(runs: 4), base: base)
        #expect(TrainerText.volumeSuggestionReason(comfortable) == "Começa na sua média das semanas normais. Com 4 corridas, o confortável vai até 62 km.")
        let cycle = TrainerVolumeSuggestion(startMeters: 64_000, peakMeters: 81_000, limit: .cycle(.increase), base: base)
        #expect(TrainerText.volumeSuggestionReason(cycle) == "Da avaliação do ciclo que terminou: aumentar o volume do último plano.")
    }

    @Test func stridesShowAsOneRowWithTheWalkBack() {
        let workout = TrainerWorkout(day: Day(iso: "2026-11-19")!, kind: .vo2max, title: "VO2 9,8 km", totalMeters: 9_800, steps: [
            TrainerStep(kind: .warmup, meters: 3_000),
            TrainerStep(kind: .work, repeats: 4, meters: 100, paceLow: 219, paceHigh: 225, method: .strides),
            TrainerStep(kind: .recovery, repeats: 4, meters: 100, method: .strides),
            TrainerStep(kind: .work, repeats: 5, meters: 1_000, restSeconds: 150, paceLow: 228, paceHigh: 234, method: .intervals),
        ], rationale: "")
        let rows = TrainerText.stepRows(workout)

        #expect(rows[1].title == "Strides 4 × 100 m")
        #expect(rows[1].detail == "3:39–3:45/km")
        #expect(rows[1].subtitle == "volta andando até o início")
        #expect(rows[1].zone == 5)
        #expect(rows.count == 3)
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
        #expect(rows.map(\.title) == ["Aquecimento", "3× Limiar", "3× Trote"])
        #expect(rows.map(\.detail) == ["3 km", "2 km · 4:14–4:20/km", "400 m"])
    }

    @Test func showsTheMethodLineAndTheRepetitionStep() {
        #expect(TrainerText.methodLine(.cruiseIntervals) == "Método: Cruise intervals (Daniels)")
        #expect(TrainerText.methodLine(.racePace) == "Método: Ritmo específico (Canova, Pfitzinger)")
        var workout = TrainerStoreTests.plan().workouts[0]
        workout.steps = [
            TrainerStep(kind: .work, repeats: 3, meters: 200, paceLow: 219, paceHigh: 225, method: .repetition),
            TrainerStep(kind: .recovery, repeats: 2, meters: 200),
        ]
        let rows = TrainerText.stepRows(workout)
        #expect(rows.map(\.title) == ["3×", "Repetição R", "Trote"])
        #expect(rows[0].isHeader && rows[2].isNested)
        #expect(rows[2].detail == "200 m")
    }

    @Test func marksTheTurnInRowsAndShape() {
        var workout = TrainerStoreTests.plan().workouts[0]
        workout.steps = [
            TrainerStep(kind: .warmup, meters: 3_000),
            TrainerStep(kind: .work, repeats: 2, meters: 2_000, paceLow: 248, paceHigh: 254, turnsAfter: true),
            TrainerStep(kind: .recovery, meters: 0, restSeconds: 90),
            TrainerStep(kind: .recovery, meters: 0, restSeconds: 90),
            TrainerStep(kind: .work, repeats: 3, meters: 2_000, paceLow: 248, paceHigh: 254),
            TrainerStep(kind: .recovery, repeats: 2, meters: 0, restSeconds: 90),
            TrainerStep(kind: .cooldown, meters: 1_000),
        ]
        let rows = TrainerText.stepRows(workout)
        let turn = rows.firstIndex(where: \.isTurn)
        #expect(rows.filter(\.isTurn).count == 1)
        #expect(turn.map { rows[$0].detail } == "7 km")
        #expect(turn.map { rows[$0 + 1].title } == "3×")
        #expect(rows.last?.title == "Volta leve")
        let bars = TrainerText.shapeBars(workout.steps)
        #expect(bars.filter(\.turnsAfter).count == 1)
        #expect(bars.firstIndex(where: \.turnsAfter) == 3)

        workout.steps = [
            TrainerStep(kind: .steady, meters: 5_000, turnsAfter: true),
            TrainerStep(kind: .steady, meters: 5_000),
        ]
        #expect(TrainerText.stepRows(workout).map(\.isTurn) == [false, true, false])
        #expect(TrainerText.stepRows(workout).map(\.title) == ["Ida", TrainerText.turnTitle, "Volta"])
        #expect(TrainerText.shapeBars(workout.steps).count == 2)
    }

    @Test func interleavesRepeatsInShape() {
        let bars = TrainerText.shapeBars(TrainerStoreTests.plan().workouts[0].steps)
        #expect(bars.map(\.kind) == [.warmup, .work, .recovery, .work, .recovery, .work])
    }

    @Test func showsRestStepAsStandingByTime() {
        var workout = TrainerStoreTests.plan().workouts[0]
        workout.steps[2] = TrainerStep(kind: .recovery, repeats: 2, meters: 0, restSeconds: 90)
        let rows = TrainerText.stepRows(workout)
        #expect(rows.map(\.title) == ["Aquecimento", "3×", "Limiar", "Descanso parado"])
        #expect(rows[3].detail == "1:30")
        let bars = TrainerText.shapeBars(workout.steps)
        #expect(bars.filter(\.isRest).count == 2)
        #expect(bars.filter(\.isRest).allSatisfy { $0.kind == .recovery && $0.meters == 0 })
    }

    @Test func skipsTheTransitionRestAfterASeries() {
        var workout = TrainerStoreTests.plan().workouts[0]
        workout.kind = .vo2max
        workout.steps = [
            TrainerStep(kind: .work, repeats: 3, meters: 1_500, paceLow: 233, paceHigh: 239),
            TrainerStep(kind: .recovery, repeats: 2, meters: 0, restSeconds: 240),
            TrainerStep(kind: .recovery, meters: 0, restSeconds: 240),
            TrainerStep(kind: .work, repeats: 3, meters: 200, paceLow: 227, paceHigh: 233, method: .repetition),
        ]
        let titles = TrainerText.stepRows(workout).map(\.title)
        #expect(titles == ["3×", "VO2 máx", "Descanso parado", "3× Repetição R"])
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

    @Test func labelsEditedWorkoutsAndTriggers() {
        var workout = TrainerStoreTests.plan().workouts[0]
        workout.edited = true
        #expect(TrainerText.status(for: TrainerDayRow(workout: workout, status: .planned, run: nil, isChanged: false)) == nil)
        #expect(TrainerText.status(for: TrainerDayRow(workout: workout, status: .today, run: nil, isChanged: false))?.text == "hoje")
        #expect(TrainerText.triggerText(.edited(TrainerEdit())) == "plano editado por você")
        #expect(TrainerText.triggerText(.edited(TrainerEdit(days: [workout.day]))) == "treino editado por você")
    }

    @Test func summarizesEditPreview() {
        let changes = [
            TrainerChange(kind: .changed, title: "Pace do limiar", before: "4:06/km", after: "4:02/km", reason: ""),
            TrainerChange(kind: .skeleton, title: "Semana 3", reason: ""),
            TrainerChange(kind: .newWeek, title: "Semana 14", reason: ""),
            TrainerChange(kind: .unchanged, title: "Treino editado mantido", reason: ""),
        ]
        #expect(TrainerText.previewLines(changes) == ["Pace do limiar: 4:06/km → 4:02/km", "Semana 3"])
        #expect(TrainerText.editTotal(total: 11_000, warmup: 3_000) == "Total: 11 km com 3 km de aquecimento.")
        #expect(TrainerText.editTotal(total: 8_500, warmup: nil) == "Total: 8,5 km.")
    }

    private static let day = Day(iso: "2026-11-17")!

    private static func workout(
        _ kind: TrainerDayKind, meters: Double, steps: [TrainerStep] = [], low: Double? = nil, high: Double? = nil,
        method: TrainerMethod? = nil, edited: Bool = false
    ) -> TrainerWorkout {
        TrainerWorkout(
            day: day, kind: kind, title: "", totalMeters: meters, steps: steps, paceLow: low, paceHigh: high,
            note: "só se a prontidão ≥ 60", rationale: "", method: method, edited: edited
        )
    }

    private func texts(_ line: TrainerDayLine) -> [String] {
        [line.title, line.detail] + line.tags.map(\.text)
    }

    @Test func buildsTheEasyDayLine() {
        let line = TrainerText.dayLine(Self.workout(.easy, meters: 10_000, low: 290, high: 304))
        #expect(texts(line) == ["Rodagem · 10 km", "4:50–5:04/km"])
    }

    @Test func buildsTheThresholdDayLine() {
        let steps = [
            TrainerStep(kind: .warmup, meters: 3_000),
            TrainerStep(kind: .work, repeats: 8, meters: 1_000, paceLow: 243, paceHigh: 249),
            TrainerStep(kind: .recovery, repeats: 7, meters: 0, restSeconds: 60),
        ]
        let line = TrainerText.dayLine(Self.workout(.threshold, meters: 11_000, steps: steps, low: 243, high: 249))
        #expect(texts(line) == ["Limiar · 11 km", "8 × 1 km a 4:03–4:09"])
    }

    @Test func buildsTheVo2DayLineWithTheClosingRepetitions() {
        let steps = [
            TrainerStep(kind: .warmup, meters: 3_000),
            TrainerStep(kind: .work, repeats: 3, meters: 1_500, paceLow: 233, paceHigh: 239, method: .intervals),
            TrainerStep(kind: .recovery, repeats: 2, meters: 0, restSeconds: 240),
            TrainerStep(kind: .recovery, meters: 0, restSeconds: 240),
            TrainerStep(kind: .work, repeats: 3, meters: 200, paceLow: 219, paceHigh: 225, method: .repetition),
        ]
        let line = TrainerText.dayLine(Self.workout(.vo2max, meters: 8_500, steps: steps, low: 233, high: 239, method: .intervals))
        #expect(texts(line) == ["VO2 máx · 8,5 km", "3 × 1,5 km a 3:53–3:59", "+ 3 × 200 m"])
    }

    @Test func buildsTheMixedSeriesDayLine() {
        let steps = [
            TrainerStep(kind: .warmup, meters: 3_000),
            TrainerStep(kind: .work, repeats: 3, meters: 1_500, paceLow: 233, paceHigh: 239),
            TrainerStep(kind: .recovery, repeats: 2, meters: 0, restSeconds: 240),
            TrainerStep(kind: .work, repeats: 2, meters: 1_000, paceLow: 233, paceHigh: 239),
        ]
        let line = TrainerText.dayLine(Self.workout(.vo2max, meters: 10_500, steps: steps, low: 233, high: 239))
        #expect(line.detail == "3 × 1,5 km + 2 × 1 km a 3:53–3:59")
    }

    @Test func buildsTheContinuousLongRunLine() {
        let line = TrainerText.dayLine(Self.workout(.long, meters: 21_000, steps: [TrainerStep(kind: .steady, meters: 21_000)], low: 268, high: 282), longStage: 3)
        #expect(texts(line) == ["Longão · 21 km", "4:28–4:42/km"])
    }

    @Test func buildsTheLongRunInBlocksLine() {
        var steps: [TrainerStep] = []
        for _ in 0..<4 {
            steps.append(TrainerStep(kind: .steady, meters: 2_000, paceLow: 273, paceHigh: 287))
            steps.append(TrainerStep(kind: .steady, meters: 2_000, paceLow: 268, paceHigh: 282))
            steps.append(TrainerStep(kind: .recovery, meters: 0, restSeconds: 60))
        }
        steps.append(TrainerStep(kind: .steady, meters: 5_000, paceLow: 268, paceHigh: 282))
        let line = TrainerText.dayLine(Self.workout(.long, meters: 21_000, steps: steps, low: 268, high: 282, edited: true), longStage: 1)
        #expect(texts(line) == ["Longão · 21 km", "4 × 4 km + 5 km a 4:28–4:47", "etapa 1 de 6", "editado"])
    }

    @Test func buildsTheOptionalDayLineWithStrength() {
        let strength = [TrainerStrengthLine(id: UUID(), name: "Full body", isDone: false)]
        let line = TrainerText.dayLine(Self.workout(.optionalEasy, meters: 7_000, low: 290, high: 304), strength: strength)
        #expect(texts(line) == ["Rodagem · 7 km", "4:50–5:04/km", "opcional", "+ Full body"])
        #expect(line.tags.map(\.style) == [.plain, .strength])
    }

    @Test func buildsTheRestDayLine() {
        let line = TrainerText.dayLine(Self.workout(.off, meters: 0, edited: true))
        #expect(texts(line) == ["Folga", ""])
    }

    @Test func namesTheRacePaceAndGoalPaceSessions() {
        let steps = [TrainerStep(kind: .work, repeats: 1, meters: 5_000, paceLow: 281, paceHigh: 287, method: .racePace)]
        #expect(TrainerText.dayLine(Self.workout(.threshold, meters: 8_000, steps: steps, low: 281, high: 287, method: .racePace)).title == "Ritmo de prova · 8 km")
        #expect(TrainerText.dayLine(Self.workout(.vo2max, meters: 8_000, steps: steps, low: 281, high: 287, method: .goalPace)).title == "Pace-alvo · 8 km")
        #expect(TrainerText.dayLine(Self.workout(.race, meters: 21_097.5, low: 281, high: 287)).title == "Prova · 21,1 km")
    }

    @Test func showsOnlyTheTotalInTheWeekCaption() {
        #expect(TrainerText.weekCaption(plannedMeters: 67_500) == "67,5 km")
    }
}
