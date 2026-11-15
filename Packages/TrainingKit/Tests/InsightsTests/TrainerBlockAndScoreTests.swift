import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerBlockAndScoreTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func target(weeks: Int, meters: Double) -> TrainerTarget {
        TrainerTarget(kind: .race, name: "Prova", date: monday.adding(days: (weeks - 1) * 7 + 5), distanceMeters: meters, goalSeconds: 5_700)
    }

    private func run(_ id: Int64, _ day: Day, km: Double, kind: RunKind = .easy) -> TrainerRun {
        TrainerRun(activityId: id, day: day, meters: km * 1_000, seconds: km * 340, kind: kind)
    }

    private var history: TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            runs.append(run(Int64(week * 10 + 1), start, km: 8))
            runs.append(run(Int64(week * 10 + 2), start.adding(days: 1), km: 10, kind: .tempo))
            runs.append(run(Int64(week * 10 + 3), start.adding(days: 5), km: 14, kind: .long))
        }
        return TrainerHistory(runs: runs, predictions: [10_000: 2_580, 5_000: 1_230])
    }

    private func plan(weeks: Int, meters: Double, history: TrainerHistory? = nil) -> TrainerPlan {
        TrainerEngine.create(
            target: target(weeks: weeks, meters: meters), structure: TrainerEngine.defaultStructure, strength: [],
            history: history ?? self.history, today: monday, now: now, startMeters: 30_000, peakMeters: 50_000
        )
    }

    @Test func marathonBeyondBlockStartsWithGeneralWeeks() {
        let result = plan(weeks: 30, meters: 42_195)
        let general = result.weeks.prefix { $0.phase == .general }

        #expect(result.weeks.count == 30)
        #expect(general.count == 12)
        #expect(result.weeks[12].phase == .base)
        #expect(result.weeks.suffix(18).allSatisfy { $0.phase != .general })
        #expect(result.versions[0].summary.contains("Bloco específico começa em \(TrainerEngineText.date(result.weeks[12].start))."))
    }

    @Test func generalWeeksHoldVolumeLongAndStage() {
        let result = plan(weeks: 30, meters: 42_195)
        let general = result.weeks.filter { $0.phase == .general }
        let steady = general.filter { !$0.isRecovery }

        #expect(steady.allSatisfy { $0.targetMeters == 30_000 })
        #expect(Set(steady.map(\.longMeters)).count == 1)
        #expect(Set(general.map(\.thresholdFocus)).count == 1)
        #expect(general.filter(\.isRecovery).count == 3)
        #expect(result.weeks[12].targetMeters <= result.weeks[17].targetMeters)
    }

    @Test func blockLengthDependsOnDistance() {
        #expect(plan(weeks: 20, meters: 21_097.5).weeks.filter { $0.phase == .general }.count == 6)
        #expect(plan(weeks: 14, meters: 21_097.5).weeks.filter { $0.phase == .general }.isEmpty)
        #expect(plan(weeks: 18, meters: 10_000).weeks.filter { $0.phase == .general }.count == 6)
        #expect(plan(weeks: 18, meters: 42_195).weeks.filter { $0.phase == .general }.isEmpty)
    }

    @Test func generalPhaseSurvivesRoundTripAndUnknownPhaseFallsBack() throws {
        let result = plan(weeks: 30, meters: 42_195)
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: data)
        #expect(decoded.weeks.first?.phase == .general)

        let phase = try JSONDecoder().decode(TrainerPhase.self, from: Data("\"futura\"".utf8))
        #expect(phase == .base)
    }

    private func weekOnePlan() -> TrainerPlan { plan(weeks: 12, meters: 21_097.5) }

    private func workout(_ plan: TrainerPlan, _ kind: TrainerDayKind) throws -> TrainerWorkout {
        try #require(plan.workouts.first { $0.kind == kind && $0.day.weekStart == monday })
    }

    private func qualityRun(_ workout: TrainerWorkout, id: Int64, on: Int, total: Int) -> TrainerRun {
        TrainerRun(
            activityId: id, day: workout.day, meters: workout.totalMeters, seconds: workout.totalMeters * 0.3, kind: .tempo,
            activeOnTarget: on, activeTotal: total
        )
    }

    @Test func scoreboardCountsKilometersQualityAndLong() throws {
        let base = weekOnePlan()
        let threshold = try workout(base, .threshold)
        let vo2 = try workout(base, .vo2max)
        let long = try workout(base, .long)
        let runs = [
            qualityRun(threshold, id: 1, on: 4, total: 4), qualityRun(vo2, id: 2, on: 2, total: 5),
            TrainerRun(activityId: 3, day: long.day, meters: long.totalMeters, seconds: 6_000, kind: .long),
        ]
        let board = try #require(TrainerEngine.scoreboard(plan: base, history: TrainerHistory(runs: runs), week: 1))

        #expect(board.qualityTotal == 2)
        #expect(board.qualityOnTarget == 1)
        #expect(board.longClosed == true)
        #expect(board.doneMeters == threshold.totalMeters + vo2.totalMeters + long.totalMeters)
        #expect(board.plannedMeters >= board.doneMeters)
        #expect(board.predictionDeltaSeconds == nil)
    }

    @Test func scoreboardLongNotClosedWithPauseOrShortRun() throws {
        let base = weekOnePlan()
        let long = try workout(base, .long)
        var paused = TrainerRun(activityId: 3, day: long.day, meters: long.totalMeters, seconds: 6_000, kind: .long)
        paused.pauses = 2
        let short = TrainerRun(activityId: 4, day: long.day, meters: long.totalMeters * 0.8, seconds: 6_000, kind: .long)

        #expect(TrainerEngine.scoreboard(plan: base, history: TrainerHistory(runs: [paused]), week: 1)?.longClosed == false)
        #expect(TrainerEngine.scoreboard(plan: base, history: TrainerHistory(runs: [short]), week: 1)?.longClosed == false)
        #expect(TrainerEngine.scoreboard(plan: base, history: TrainerHistory(runs: []), week: 1)?.longClosed == false)
    }

    @Test func scoreboardPredictionDeltaUsesSeries() throws {
        let base = weekOnePlan()
        let series: [Day: [Double: Double]] = [monday: [21_097.5: 5_700, 10_000: 2_600], monday.adding(days: 7): [21_097.5: 5_682, 10_000: 2_590]]
        let board = try #require(TrainerEngine.scoreboard(
            plan: base, history: TrainerHistory(runs: [], predictionSeries: series), week: 1
        ))

        #expect(board.predictionDeltaSeconds == -18)
        #expect(board.predictionMeters == 21_097.5)
    }

    @Test func scoreboardsListClosedWeeksNewestFirst() {
        let base = weekOnePlan()
        let boards = TrainerEngine.scoreboards(plan: base, history: TrainerHistory(runs: []), today: monday.adding(days: 15))

        #expect(boards.map(\.weekIndex) == [2, 1])
        #expect(TrainerEngine.scoreboards(plan: base, history: TrainerHistory(runs: []), today: monday.adding(days: 3)).isEmpty)
    }

    private func external(_ day: Day, name: String, meters: Double, steps: [TrainerStep] = []) -> TrainerExternalWorkout {
        TrainerExternalWorkout(day: day, name: name, totalMeters: meters, steps: steps)
    }

    @Test func classifiesExternalByNameThenStepsThenDistance() {
        let base = weekOnePlan()
        let vo2Pace = base.paces.vo2max - 5
        let thresholdPace = base.paces.threshold + 5
        let fast = [TrainerStep(kind: .work, repeats: 5, meters: 1_000, restSeconds: 150, paceLow: vo2Pace - 2, paceHigh: vo2Pace + 2)]
        let steady = [TrainerStep(kind: .work, repeats: 4, meters: 2_000, restSeconds: 120, paceLow: thresholdPace - 2, paceHigh: thresholdPace + 2)]
        let longMeters = base.weeks[0].longMeters

        #expect(TrainerEngine.classify(external(monday, name: "Limiar 8x1km", meters: 10_000), plan: base) == .threshold)
        #expect(TrainerEngine.classify(external(monday, name: "Tiros", meters: 10_000), plan: base) == .vo2max)
        #expect(TrainerEngine.classify(external(monday, name: "Longão", meters: 10_000), plan: base) == .long)
        #expect(TrainerEngine.classify(external(monday, name: "Treino A", meters: 9_000, steps: fast), plan: base) == .vo2max)
        #expect(TrainerEngine.classify(external(monday, name: "Treino A", meters: 9_000, steps: steady), plan: base) == .threshold)
        #expect(TrainerEngine.classify(external(monday, name: "Treino B", meters: longMeters), plan: base) == .long)
        #expect(TrainerEngine.classify(external(monday, name: "Treino B", meters: 6_000), plan: base) == .easy)
        #expect(TrainerEngine.classify(external(monday, name: "Vazio", meters: 0), plan: base) == .off)
        let single = [TrainerStep(kind: .work, meters: 8_000, paceLow: base.paces.easy - 5, paceHigh: base.paces.easy + 5)]
        #expect(TrainerEngine.classify(external(monday, name: "Treino C", meters: 8_000, steps: single), plan: base) == .easy)
        let tempo = [TrainerStep(kind: .work, meters: 6_000, paceLow: base.paces.threshold - 3, paceHigh: base.paces.threshold + 3)]
        #expect(TrainerEngine.classify(external(monday, name: "Treino C", meters: 9_000, steps: tempo), plan: base) == .threshold)
    }

    @Test func compareCountsSameKindAndLabelsDays() throws {
        let base = weekOnePlan()
        let easy = try workout(base, .easy)
        let threshold = try workout(base, .threshold)
        let long = try workout(base, .long)
        let items = [
            external(easy.day, name: "Rodagem", meters: easy.totalMeters),
            external(threshold.day, name: "Limiar", meters: threshold.totalMeters * 2),
            external(long.day, name: "Rodagem", meters: 6_000),
        ]
        let week = TrainerEngine.compare(plan: base, external: items, history: TrainerHistory(runs: []), week: monday, today: monday.adding(days: -1))
        let byDay = Dictionary(uniqueKeysWithValues: week.days.map { ($0.day, $0) })

        #expect(byDay[easy.day]?.match == .same)
        #expect(byDay[threshold.day]?.match == .similar)
        #expect(byDay[long.day]?.match == .similar)
        #expect(week.sameKindDays >= 2)
        #expect(week.externalQuality == 1)
        #expect(week.betaQuality == 2)
        #expect(week.externalMeters == items.reduce(0) { $0 + $1.totalMeters })
        #expect(byDay[threshold.day]?.betaSummary?.isEmpty == false)
    }

    @Test func compareDifferentWhenOnlyOneSideHasWorkout() throws {
        let base = weekOnePlan()
        let off = try #require(base.workouts.first { $0.kind == .off && $0.day.weekStart == monday })
        let week = TrainerEngine.compare(
            plan: base, external: [external(off.day, name: "Rodagem", meters: 8_000)], history: TrainerHistory(runs: []),
            week: monday, today: monday
        )

        #expect(week.days.first { $0.day == off.day }?.match == .different)
    }

    @Test func compareDecidesCloserByDistanceAndPace() throws {
        let base = weekOnePlan()
        let easy = try workout(base, .easy)
        let near = external(easy.day, name: "Rodagem", meters: easy.totalMeters - 3_000)

        func closer(runMeters: Double) -> TrainerComparisonCloser? {
            let item = TrainerRun(activityId: 9, day: easy.day, meters: runMeters, seconds: runMeters * 0.34, kind: .easy)
            let week = TrainerEngine.compare(plan: base, external: [near], history: TrainerHistory(runs: [item]), week: monday, today: monday.adding(days: 6))
            return week.days.first { $0.day == easy.day }?.closer
        }

        #expect(closer(runMeters: easy.totalMeters) == .beta)
        #expect(closer(runMeters: near.totalMeters) == .external)
    }

    @Test func compareHasNoCloserBeforeTheRun() throws {
        let base = weekOnePlan()
        let easy = try workout(base, .easy)
        let week = TrainerEngine.compare(
            plan: base, external: [external(easy.day, name: "Rodagem", meters: 5_000)], history: TrainerHistory(runs: []),
            week: monday, today: monday
        )

        #expect(week.days.allSatisfy { $0.closer == nil })
    }

    private func readinessHistory(_ day: Day, score: Int, runs: [TrainerRun] = []) -> TrainerHistory {
        TrainerHistory(runs: runs, readiness: [day: score])
    }

    @Test func readinessSuggestsSwapWhenTomorrowIsEasy() throws {
        let base = weekOnePlan()
        let strong = try workout(base, .threshold)
        let suggestion = try #require(TrainerEngine.readinessSuggestion(
            plan: base, history: readinessHistory(strong.day, score: 42), today: strong.day,
            factor: TrainerReadinessFactor(name: "sono", value: 61)
        ))

        #expect(suggestion.score == 42)
        #expect(suggestion.swapDay == strong.day.adding(days: 1))
        #expect(suggestion.factor?.name == "sono")
    }

    @Test func readinessKeepsRestWhenTomorrowIsNotEasy() throws {
        let base = weekOnePlan()
        let long = try workout(base, .long)
        let suggestion = try #require(TrainerEngine.readinessSuggestion(plan: base, history: readinessHistory(long.day, score: 40), today: long.day))

        #expect(suggestion.swapDay == nil)
    }

    @Test func readinessIgnoredWhenNotApplicable() throws {
        let base = weekOnePlan()
        let strong = try workout(base, .threshold)
        let easy = try workout(base, .easy)
        let done = [TrainerRun(activityId: 1, day: strong.day, meters: 5_000, seconds: 1_500, kind: .tempo)]
        var edited = base
        edited.workouts = base.workouts.map { item in
            var copy = item
            if item.day == strong.day { copy.edited = true }
            return copy
        }

        #expect(TrainerEngine.readinessSuggestion(plan: base, history: readinessHistory(strong.day, score: 50), today: strong.day) == nil)
        #expect(TrainerEngine.readinessSuggestion(plan: base, history: readinessHistory(strong.day.adding(days: -1), score: 30), today: strong.day) == nil)
        #expect(TrainerEngine.readinessSuggestion(plan: base, history: readinessHistory(easy.day, score: 30), today: easy.day) == nil)
        #expect(TrainerEngine.readinessSuggestion(plan: base, history: readinessHistory(strong.day, score: 30, runs: done), today: strong.day) == nil)
        #expect(TrainerEngine.readinessSuggestion(plan: edited, history: readinessHistory(strong.day, score: 30), today: strong.day) == nil)
    }

    @Test func acceptingReadinessSwapMovesStrongWorkoutToTomorrow() throws {
        let base = weekOnePlan()
        let strong = try workout(base, .threshold)
        let tomorrow = strong.day.adding(days: 1)
        let result = TrainerEngine.adjust(
            base, history: readinessHistory(strong.day, score: 42), today: strong.day, now: now,
            trigger: .readiness(day: strong.day, score: 42)
        )
        let today = try #require(result.workouts.first { $0.day == strong.day })
        let moved = try #require(result.workouts.first { $0.day == tomorrow })
        let version = try #require(result.versions.last)

        #expect(today.kind == .easy)
        #expect(today.totalMeters == 8_000)
        #expect(!today.edited)
        #expect(moved.kind == .threshold)
        #expect(moved.title == strong.title)
        #expect(!moved.edited)
        #expect(version.number == base.versions.count + 1)
        #expect(version.trigger == .readiness(day: strong.day, score: 42))
        #expect(version.changes.allSatisfy { $0.reason == "Trocado pela prontidão (42)." })
        #expect(version.changes.count == 2)
    }

    @Test func acceptingReadinessWithoutSwapOnlyLightensToday() throws {
        let base = weekOnePlan()
        let long = try workout(base, .long)
        let result = TrainerEngine.adjust(
            base, history: readinessHistory(long.day, score: 40), today: long.day, now: now, trigger: .readiness(day: long.day, score: 40)
        )

        #expect(result.workouts.first { $0.day == long.day }?.totalMeters == 8_000)
        #expect(result.workouts.first { $0.day == long.day.adding(days: 1) }?.kind == base.workouts.first { $0.day == long.day.adding(days: 1) }?.kind)
        #expect(result.versions.last?.changes.count == 1)
    }

    @Test func readinessTriggerIsIgnoredWhenNotApplicable() throws {
        let base = weekOnePlan()
        let easy = try workout(base, .easy)
        let result = TrainerEngine.adjust(
            base, history: readinessHistory(easy.day, score: 30), today: easy.day, now: now, trigger: .readiness(day: easy.day, score: 30)
        )

        #expect(result == base)
    }

    @Test func readinessTriggerRoundTrips() throws {
        let trigger = TrainerTrigger.readiness(day: monday, score: 42)
        let decoded = try JSONDecoder().decode(TrainerTrigger.self, from: JSONEncoder().encode(trigger))

        #expect(decoded == trigger)
    }
}
