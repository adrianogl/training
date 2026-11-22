import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerOutAndBackTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let structure: [Int: TrainerDayKind] = [1: .easy, 2: .threshold, 3: .easy, 4: .vo2max, 5: .easy, 6: .long, 7: .off]

    private var history: TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(run(base + 1, start, km: 9, pace: 320, kind: .easy))
            runs.append(run(base + 2, start.adding(days: 1), km: 10, pace: 250, kind: .tempo))
            runs.append(run(base + 3, start.adding(days: 2), km: 8, pace: 320, kind: .easy))
            runs.append(run(base + 4, start.adding(days: 3), km: 8, pace: 240, kind: .intervals))
            runs.append(run(base + 5, start.adding(days: 5), km: 14, pace: 315, kind: .long))
        }
        return TrainerHistory(runs: runs, predictions: [10_000: 2_460, 5_000: 1_180])
    }

    private func run(_ id: Int64, _ day: Day, km: Double, pace: Double, kind: RunKind) -> TrainerRun {
        TrainerRun(activityId: id, day: day, meters: km * 1_000, seconds: km * pace, kind: kind)
    }

    private var tenK: TrainerTarget {
        TrainerTarget(kind: .paceDistance, name: "10 km a 4:00", distanceMeters: 10_000, goalPace: 240)
    }

    private func plan(target: TrainerTarget, start: Double = 60_000, peak: Double = 80_000) -> TrainerPlan {
        TrainerEngine.create(
            target: target, structure: structure, strength: [], history: history, today: monday, now: now,
            startMeters: start, peakMeters: peak, outAndBack: true
        )
    }

    private func distanceBeforeTurn(_ workout: TrainerWorkout) -> Double? {
        var distance = 0.0
        for step in workout.steps {
            distance += step.meters * Double(step.repeats)
            if step.turnsAfter == true { return distance }
        }
        return nil
    }

    private func total(_ workout: TrainerWorkout) -> Double {
        workout.steps.reduce(0.0) { $0 + $1.meters * Double($1.repeats) }
    }

    private var continuous: Set<TrainerDayKind> { [.easy, .optionalEasy, .long] }

    @Test func continuousRunsUseEvenKilometersAndTurnAtTheHalf() throws {
        let plan = plan(target: tenK)
        let runs = plan.workouts.filter { continuous.contains($0.kind) }

        #expect(!runs.isEmpty)
        for run in runs {
            #expect(run.totalMeters.truncatingRemainder(dividingBy: 2_000) == 0, "\(run.day.iso) \(run.totalMeters)")
            let turn = try #require(distanceBeforeTurn(run), "\(run.day.iso)")
            #expect(abs(turn * 2 - total(run)) < 1, "\(run.day.iso)")
        }
    }

    @Test func qualityTurnsAtTheEndOfARepWithAtMostTwoExtraKilometers() throws {
        let plan = plan(target: tenK)
        let plain = TrainerEngine.create(
            target: tenK, structure: structure, strength: [], history: history, today: monday, now: now, startMeters: 60_000, peakMeters: 80_000
        )
        let quality = plan.workouts.filter { $0.kind == .threshold || $0.kind == .vo2max }

        #expect(!quality.isEmpty)
        for workout in quality {
            let turn = try #require(distanceBeforeTurn(workout), "\(workout.day.iso)")
            #expect(abs(turn * 2 - total(workout)) < 1, "\(workout.day.iso)")
            let work = { (w: TrainerWorkout) in w.steps.filter { $0.kind == .work }.reduce(0.0) { $0 + $1.meters * Double($1.repeats) } }
            let original = try #require(plain.workouts.first { $0.day == workout.day })
            #expect(work(workout) == work(original), "\(workout.day.iso)")
            #expect(workout.totalMeters - original.totalMeters <= 2_000, "\(workout.day.iso)")
        }
    }

    @Test func thresholdSplitsTheSeriesAtTheTurn() throws {
        let plan = plan(target: tenK)
        let threshold = try #require(plan.workouts.first { $0.kind == .threshold })
        let kinds = threshold.steps.map(\.kind)

        #expect(threshold.steps.first { $0.turnsAfter == true }?.kind == .work)
        #expect(kinds.filter { $0 == .work }.count == 2)
        #expect(kinds.last == .cooldown || threshold.steps.first?.meters ?? 0 > 3_000)
    }

    @Test func weekVolumeStaysWithinTwoKilometers() {
        let plan = plan(target: tenK)
        for week in plan.weeks {
            let sum = plan.workouts.filter { $0.day.weekStart == week.start }.reduce(0.0) { $0 + $1.totalMeters }
            #expect(abs(sum - week.targetMeters) <= 2_000, "semana \(week.index): \(sum) de \(week.targetMeters)")
        }
    }

    @Test func cappedLongRunRoundsDown() {
        let paces = TrainerPaces(easy: 300, long: 290, threshold: 245, vo2max: 228)
        let week = TrainerWeek(
            index: 1, start: monday, phase: .base, isRecovery: false, plannedMeters: 60_000, longMeters: 15_000, thresholdFocus: "", vo2Focus: "",
            outAndBack: true
        )

        #expect(TrainerEngine.evenLongs([week], paces: paces)[0].longMeters == 16_000)
        #expect(TrainerEngine.evenLongs([week], paces: paces, firstCap: 15_000)[0].longMeters == 14_000)
    }

    @Test func offByDefault() {
        let plain = TrainerEngine.create(
            target: tenK, structure: structure, strength: [], history: history, today: monday, now: now, startMeters: 60_000, peakMeters: 80_000
        )

        #expect(plain.workouts.allSatisfy { !TrainerEngine.hasTurn($0) })
        #expect(!plain.outAndBack)
    }

    @Test func editingKeepsTheTurnAtTheNewHalf() throws {
        let plan = plan(target: tenK)
        let easy = try #require(plan.workouts.first { $0.kind == .easy && $0.variant == nil })
        var draft = try #require(TrainerEngine.draft(of: easy))
        draft.totalMeters = 13_000
        let edited = TrainerEngine.applying(draft, to: easy)

        #expect(edited.totalMeters == 13_000)
        #expect(distanceBeforeTurn(edited) == 6_500)

        let threshold = try #require(plan.workouts.first { $0.kind == .threshold && $0.steps.filter { $0.kind == .work }.count == 2 })
        var quality = try #require(TrainerEngine.draft(of: threshold))
        let repeats = threshold.steps.filter { $0.kind == .work }.reduce(0) { $0 + $1.repeats }
        #expect(quality.repeats == repeats)
        quality.repeats = 6
        let shorter = TrainerEngine.applying(quality, to: threshold)
        let turn = try #require(distanceBeforeTurn(shorter))
        #expect(abs(turn * 2 - total(shorter)) < 1)
    }

    @Test func planKeepsTheOptionWhenSaved() throws {
        let original = plan(target: tenK)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: data)

        #expect(decoded.outAndBack)
        #expect(decoded.weeks.allSatisfy { $0.outAndBack })
        #expect(decoded.workouts == original.workouts)
    }
}
