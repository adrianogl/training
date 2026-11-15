import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerLongBlocksTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var halfMarathon: TrainerTarget {
        TrainerTarget(kind: .race, name: "Meia maratona", date: monday.adding(days: 12 * 7 + 5), distanceMeters: 21_097.5, goalSeconds: 5_700)
    }

    private func run(
        _ id: Int64, _ day: Day, km: Double, pace: Double = 335, kind: RunKind = .long, fadeKm: Int? = nil, pauses: Int? = nil,
        firstPauseKm: Int? = nil
    ) -> TrainerRun {
        TrainerRun(
            activityId: id, day: day, meters: km * 1_000, seconds: km * pace, kind: kind, fadeKm: fadeKm, pauses: pauses,
            firstPauseKm: firstPauseKm
        )
    }

    private func history(extra: [TrainerRun] = []) -> TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(run(base + 1, start, km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 2, start.adding(days: 1), km: 10, pace: 262, kind: .tempo))
            runs.append(run(base + 3, start.adding(days: 2), km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 4, start.adding(days: 5), km: Double(18 - week), pace: 335, kind: .long))
        }
        return TrainerHistory(runs: runs + extra, predictions: [10_000: 2_580, 5_000: 1_230])
    }

    private func plan(mode: TrainerLongMode = .blocks, history: TrainerHistory? = nil) -> TrainerPlan {
        TrainerEngine.create(
            target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], history: history ?? self.history(),
            today: monday, now: now, longMode: mode
        )
    }

    private func longWorkout(_ plan: TrainerPlan, weekOffset: Int = 0) -> TrainerWorkout {
        let day = monday.adding(days: 5 + 7 * weekOffset)
        return plan.workouts.first { $0.day == day }!
    }

    private func steadyKilometers(_ workout: TrainerWorkout) -> Double {
        workout.steps.reduce(0.0) { $0 + $1.meters * Double($1.repeats) }
    }

    @Test func dividesTheLongRunByStage() {
        let km = { (blocks: [Double]) in blocks.map { $0 / 1_000 } }
        #expect(km(TrainerEngine.longBlocks(stage: 1, meters: 20_000)) == [4, 4, 4, 4, 4])
        #expect(km(TrainerEngine.longBlocks(stage: 2, meters: 20_000)) == [5, 5, 5, 5])
        #expect(km(TrainerEngine.longBlocks(stage: 3, meters: 20_000)) == [7, 7, 6])
        #expect(km(TrainerEngine.longBlocks(stage: 4, meters: 20_000)) == [10, 10])
        #expect(km(TrainerEngine.longBlocks(stage: 5, meters: 20_000)) == [14, 6])
        #expect(km(TrainerEngine.longBlocks(stage: 6, meters: 20_000)) == [20])
        #expect(km(TrainerEngine.longBlocks(stage: 1, meters: 24_000)) == [5, 5, 5, 5, 4])
        #expect(km(TrainerEngine.longBlocks(stage: 2, meters: 24_000)) == [6, 6, 6, 6])
        #expect(km(TrainerEngine.longBlocks(stage: 3, meters: 24_000)) == [8.5, 8.5, 7])
        #expect(km(TrainerEngine.longBlocks(stage: 4, meters: 24_000)) == [12, 12])
        #expect(km(TrainerEngine.longBlocks(stage: 5, meters: 24_000)) == [17, 7])
        #expect(km(TrainerEngine.longBlocks(stage: 6, meters: 24_000)) == [24])
        #expect(TrainerEngine.longRest(stage: 4) == 60)
        #expect(TrainerEngine.longRest(stage: 5) == 30)
        #expect(TrainerEngine.longRest(stage: 6) == nil)
    }

    @Test func keepsTheNumberOfPausesWhenTheDistanceGrows() {
        for stage in 1...6 {
            let short = TrainerEngine.longBlocks(stage: stage, meters: 20_000)
            let long = TrainerEngine.longBlocks(stage: stage, meters: 26_000)
            #expect(short.count == long.count)
            #expect((long.max() ?? 0) >= (short.max() ?? 0))
        }
    }

    @Test func startsAtTheStageBelowTheTypicalFade() {
        let hist = { (fade: Int?) in
            TrainerHistory(runs: (1...4).map { run(Int64($0), monday.adding(days: -7 * $0), km: 20, fadeKm: fade) })
        }
        #expect(TrainerEngine.initialLongStage(history: hist(nil), plan: nil, today: monday, meters: 20_000) == 1)
        #expect(TrainerEngine.initialLongStage(history: hist(6), plan: nil, today: monday, meters: 20_000) == 1)
        #expect(TrainerEngine.initialLongStage(history: hist(11), plan: nil, today: monday, meters: 20_000) == 1)
        #expect(TrainerEngine.initialLongStage(history: hist(13), plan: nil, today: monday, meters: 20_000) == 2)
        #expect(TrainerEngine.initialLongStage(history: hist(18), plan: nil, today: monday, meters: 20_000) == 3)
        #expect(TrainerEngine.initialLongStage(history: hist(25), plan: nil, today: monday, meters: 20_000) == 4)
        #expect(TrainerEngine.initialLongStage(history: hist(3), plan: nil, today: monday, meters: 20_000) == 1)
    }

    @Test func mixesFadeAndFirstPauseInTheTypicalFade() {
        let runs = [
            run(1, monday.adding(days: -7), km: 18, fadeKm: 12, pauses: 1, firstPauseKm: 8),
            run(2, monday.adding(days: -14), km: 18, fadeKm: 14),
            run(3, monday.adding(days: -21), km: 18),
        ]
        let typical = TrainerEngine.typicalFadeKm(history: TrainerHistory(runs: runs), plan: nil, today: monday)
        #expect(typical == 12)
    }

    @Test func createsTheBlocksWorkoutWithPausesAndNoExtraKilometers() {
        let created = plan()
        let workout = longWorkout(created)
        let stage = created.longStage
        #expect(created.longMode == .blocks)
        #expect(workout.title.hasSuffix("em blocos"))
        let blocks = TrainerEngine.longBlocks(stage: stage, meters: workout.totalMeters)
        #expect(TrainerEngine.plannedPauses(of: workout) == blocks.count - 1)
        #expect(TrainerEngine.blockSizes(of: workout) == blocks)
        #expect(steadyKilometers(workout) == workout.totalMeters)
        #expect(workout.steps.filter { $0.restSeconds != nil }.allSatisfy { $0.meters == 0 && $0.restSeconds == 60 })
    }

    @Test func addsFiveSecondsToTheFirstTwoKilometersOfEachBlock() {
        let workout = longWorkout(plan())
        let opening = workout.steps.filter { $0.kind == .steady && $0.meters == 2_000 && $0.paceLow == workout.steps[0].paceLow }
        let steady = workout.steps.filter { $0.kind == .steady }
        let blocks = TrainerEngine.blockSizes(of: workout)
        #expect(opening.count == blocks.count)
        let main = steady.first { $0.paceLow != workout.steps[0].paceLow }
        #expect(abs((workout.steps[0].paceLow ?? 0) - (main?.paceLow ?? 0) - 5) <= 1)
        #expect(abs((workout.steps[0].paceHigh ?? 0) - (main?.paceHigh ?? 0) - 5) <= 1)
        #expect(abs((main?.paceLow ?? 0) - (workout.paceLow ?? 0)) <= 1)
    }

    @Test func keepsTheContinuousLongRunWhenTheModeIsContinuous() {
        let created = plan(mode: .continuous)
        let workout = longWorkout(created)
        #expect(created.longMode == .continuous)
        #expect(TrainerEngine.plannedPauses(of: workout) == 0)
        #expect(!workout.title.hasSuffix("em blocos"))
    }

    private func closed(_ plan: TrainerPlan, weekOffset: Int, id: Int64) -> TrainerRun {
        let workout = longWorkout(plan, weekOffset: weekOffset)
        return run(id, workout.day, km: workout.totalMeters / 1_000, pauses: TrainerEngine.plannedPauses(of: workout))
    }

    @Test func advancesOnlyAfterTwoClosedLongRunsInARow() {
        var current = plan()
        current.longStage = 1
        let first = closed(current, weekOffset: 0, id: 901)
        let afterFirst = TrainerEngine.adjust(
            current, history: history(extra: [first]), today: monday.adding(days: 6), now: now,
            trigger: .workout(activityId: 901, day: first.day)
        )
        #expect(afterFirst.longStage == 1)
        #expect(afterFirst.longStageStreak == 1)
        #expect(afterFirst.longStageMisses == 0)
        let second = closed(afterFirst, weekOffset: 1, id: 902)
        let afterSecond = TrainerEngine.adjust(
            afterFirst, history: history(extra: [first, second]), today: monday.adding(days: 13), now: now,
            trigger: .workout(activityId: 902, day: second.day)
        )
        #expect(afterSecond.longStage == 2)
        #expect(afterSecond.longStageStreak == 0)
        let version = afterSecond.versions.last
        #expect(version?.changes.contains { $0.title.hasPrefix("Longão") && $0.before?.contains("etapa 1") == true && $0.after?.contains("etapa 2") == true } == true)
        let next = afterSecond.workouts.first { $0.kind == .long && $0.day > monday.adding(days: 13) }
        #expect(TrainerEngine.blockSizes(of: next!).count == 4)
    }

    @Test func goesBackAfterTwoFailuresInARow() {
        var current = plan()
        current.longStage = 3
        let missed = { (id: Int64, offset: Int, plan: TrainerPlan) -> TrainerRun in
            let workout = self.longWorkout(plan, weekOffset: offset)
            return self.run(id, workout.day, km: workout.totalMeters / 1_000, fadeKm: 14, pauses: TrainerEngine.plannedPauses(of: workout))
        }
        let first = missed(911, 0, current)
        let afterFirst = TrainerEngine.adjust(
            current, history: history(extra: [first]), today: monday.adding(days: 6), now: now,
            trigger: .workout(activityId: 911, day: first.day)
        )
        #expect(afterFirst.longStage == 3)
        #expect(afterFirst.longStageMisses == 1)
        let second = missed(912, 1, afterFirst)
        let afterSecond = TrainerEngine.adjust(
            afterFirst, history: history(extra: [first, second]), today: monday.adding(days: 13), now: now,
            trigger: .workout(activityId: 912, day: second.day)
        )
        #expect(afterSecond.longStage == 2)
        #expect(afterSecond.longStageMisses == 0)
        #expect(afterSecond.longStageStreak == 0)
    }

    @Test func extraPausesOrShortDistanceDoNotCloseTheLongRun() {
        var current = plan()
        current.longStage = 1
        let workout = longWorkout(current)
        let planned = TrainerEngine.plannedPauses(of: workout)
        let extra = run(921, workout.day, km: workout.totalMeters / 1_000, pauses: planned + 1)
        let outcome = TrainerEngine.closeLongBlocks(plan: current, workouts: [workout], history: history(extra: [extra]))
        #expect(outcome.long.streak == 0)
        #expect(outcome.long.misses == 1)
        let short = run(922, workout.day, km: workout.totalMeters / 1_000 * 0.85, pauses: planned)
        let shortOutcome = TrainerEngine.closeLongBlocks(plan: current, workouts: [workout], history: history(extra: [short]))
        #expect(shortOutcome.long.misses == 1)
        let ninety = run(923, workout.day, km: workout.totalMeters / 1_000 * 0.9, pauses: planned)
        #expect(TrainerEngine.closeLongBlocks(plan: current, workouts: [workout], history: history(extra: [ninety])).long.streak == 1)
    }

    @Test func recoveryAndTaperWeeksKeepTheCounters() {
        var current = plan()
        current.longStageStreak = 1
        current.longStageMisses = 1
        let workout = longWorkout(current)
        let planned = TrainerEngine.plannedPauses(of: workout)
        let bad = run(931, workout.day, km: 2, pauses: planned + 3)
        let good = run(932, workout.day, km: workout.totalMeters / 1_000, pauses: planned)
        for phase in [(true, TrainerPhase.base), (false, .taper)] {
            var week = current
            week.weeks = week.weeks.map { item in
                var copy = item
                if item.start == workout.day.weekStart { copy.isRecovery = phase.0; copy.phase = phase.1 }
                return copy
            }
            for result in [bad, good] {
                let outcome = TrainerEngine.closeLongBlocks(plan: week, workouts: [workout], history: history(extra: [result]))
                #expect(outcome.long.streak == 1)
                #expect(outcome.long.misses == 1)
                #expect(outcome.long.stage == week.longStage)
            }
        }
    }

    @Test func suggestsContinuousAfterTwoClosedRunsAtTheLastStage() {
        var current = plan()
        current.longStage = 6
        current.longStageStreak = 1
        let workout = longWorkout(current)
        let good = run(941, workout.day, km: workout.totalMeters / 1_000)
        let outcome = TrainerEngine.closeLongBlocks(plan: current, workouts: [workout], history: history(extra: [good]))
        #expect(outcome.long.stage == 6)
        #expect(outcome.long.streak == 2)
        #expect(outcome.long.mode == .blocks)
        #expect(outcome.sentences.contains { $0.contains("contínuo") })
    }

    @Test func switchingTheModeCreatesAVersionExplainingTheChange() {
        let continuous = plan(mode: .continuous)
        let switched = TrainerEngine.adjust(continuous, history: history(), today: monday, now: now, trigger: .longModeChanged)
        #expect(switched.longMode == .blocks)
        #expect(switched.versions.count == continuous.versions.count + 1)
        #expect(switched.versions.last?.trigger == .longModeChanged)
        let change = switched.versions.last?.changes.first
        #expect(change?.title == "Longão")
        #expect(change?.before == "Contínuo")
        #expect(change?.after?.hasPrefix("Em blocos") == true)
        #expect(change?.reason.isEmpty == false)
        #expect(switched.workouts.contains { $0.kind == .long && TrainerEngine.plannedPauses(of: $0) > 0 })
        let back = TrainerEngine.adjust(switched, history: history(), today: monday, now: now, trigger: .longModeChanged)
        #expect(back.longMode == .continuous)
        #expect(back.workouts.allSatisfy { TrainerEngine.plannedPauses(of: $0) == 0 })
    }

    @Test func decodesOldJsonWithoutTheLongFields() throws {
        let encoded = try JSONEncoder().encode(plan())
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for key in ["longMode", "longStage", "longStageStreak", "longStageMisses"] { object.removeValue(forKey: key) }
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.longMode == .continuous)
        #expect(decoded.longStage == 1)
        #expect(decoded.longStageStreak == 0)
        #expect(decoded.longStageMisses == 0)
        let roundTrip = try JSONDecoder().decode(TrainerPlan.self, from: JSONEncoder().encode(plan()))
        #expect(roundTrip.longMode == .blocks)
    }

    @Test func suggestsBlocksWhenTwoOfTheLastFourRunsPausedOrFaded() {
        let flagged = [
            run(1, monday.adding(days: -7), km: 18, fadeKm: 12),
            run(2, monday.adding(days: -14), km: 18, pauses: 2, firstPauseKm: 9),
            run(3, monday.adding(days: -21), km: 18),
            run(4, monday.adding(days: -28), km: 18),
        ]
        let suggestion = TrainerEngine.longModeSuggestion(history: TrainerHistory(runs: flagged), plan: nil, today: monday)
        #expect(suggestion == TrainerLongSuggestion(flagged: 2, total: 4))
        #expect(TrainerEngine.longModeSuggestion(history: TrainerHistory(runs: Array(flagged.dropFirst(1).suffix(3))), plan: nil, today: monday) == nil)
    }

    @Test func plannedPausesDoNotCountAsUnplanned() {
        var current = plan()
        current.longStage = 1
        let workout = longWorkout(current)
        let done = run(951, workout.day, km: 20, pauses: TrainerEngine.plannedPauses(of: workout), firstPauseKm: 4)
        let suggestion = TrainerEngine.longModeSuggestion(history: TrainerHistory(runs: [done]), plan: current, today: monday.adding(days: 6))
        #expect(suggestion == nil)
    }

    @Test func heatAddsPaceAndShrinksTheBlocks() {
        #expect(TrainerHeat.assess(temperature: 24).isHot == false)
        let warm = TrainerHeat.assess(temperature: 26)
        #expect(warm.paceOffset == 5)
        #expect(warm.blockReduction == 1_000)
        let hot = TrainerHeat.assess(temperature: 29)
        #expect(hot.paceOffset == 10)
        #expect(TrainerHeat.assess(temperature: 28).paceOffset == 10)
        #expect(TrainerHeat.assess(temperature: 24.5).paceOffset == 5)

        var current = plan()
        current.longStage = 2
        let workout = TrainerEngine.adjust(current, history: history(), today: monday, now: now, trigger: .strengthChanged)
        let base = longWorkout(workout)
        let adjusted = warm.apply(to: base, longPace: current.paces.long)
        let baseMax = TrainerEngine.blockSizes(of: base).max() ?? 0
        #expect((TrainerEngine.blockSizes(of: adjusted).max() ?? 0) <= baseMax - 1_000 + 1)
        #expect(steadyKilometers(adjusted) == base.totalMeters)
        #expect((adjusted.paceLow ?? 0) > (base.paceLow ?? 0))
        #expect(TrainerHeat.assess(temperature: 22).apply(to: base, longPace: current.paces.long) == base)
    }
}
