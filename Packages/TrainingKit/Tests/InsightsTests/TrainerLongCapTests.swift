import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerLongCapTests {
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
            startMeters: start, peakMeters: peak
        )
    }

    private func peakWeek(_ plan: TrainerPlan) -> (week: TrainerWeek, workouts: [TrainerWorkout]) {
        let week = plan.weeks.last { $0.targetMeters == 80_000 && !$0.isRecovery && $0.longMeters < 21_000 }!
        return (week, plan.workouts.filter { $0.day.weekStart == week.start })
    }

    @Test func tenKLongRunGrowsWithTheWeekVolume() {
        let peak = peakWeek(plan(target: tenK))
        let long = peak.workouts.first { $0.kind == .long }!

        #expect(long.totalMeters == 19_000)
        #expect(plan(target: tenK).weeks.map(\.longMeters).max() == 21_000)
    }

    @Test func longRunStaysTwoKilometersAboveEveryEasyRun() {
        let peak = peakWeek(plan(target: tenK))
        let long = peak.workouts.first { $0.kind == .long }!.totalMeters
        let easy = peak.workouts.filter { $0.kind == .easy || $0.kind == .optionalEasy }.map(\.totalMeters)

        #expect(easy.allSatisfy { $0 + 2_000 <= long })
    }

    @Test func mediumLongRunIsAtMostThreeQuartersOfTheLongRun() {
        let peak = peakWeek(plan(target: tenK))
        let long = peak.workouts.first { $0.kind == .long }!.totalMeters
        let medium = peak.workouts.first { $0.variant == .mediumLong }

        #expect(medium != nil)
        #expect((medium?.totalMeters ?? .infinity) <= long * 0.75)
    }

    @Test func raceCapStillRulesLowVolumes() {
        let low = plan(target: tenK, start: 50_000, peak: 60_000)

        #expect(low.weeks.map { $0.baseLongMeters ?? $0.longMeters }.max() == 16_000)
    }

    @Test func volumeCapStopsAtTheTimeLimitOfTheRace() {
        #expect(TrainerEngine.volumeLongCap(for: tenK, weekMeters: 80_000, longPace: 315) == 20_000)
        #expect(TrainerEngine.volumeLongCap(for: tenK, weekMeters: 120_000, longPace: 330) == 21_000)
        let marathon = TrainerTarget(kind: .race, name: "Maratona", distanceMeters: 42_195)
        #expect(TrainerEngine.volumeLongCap(for: marathon, weekMeters: 160_000, longPace: 330) == 27_000)
    }

    @Test func longerRacesKeepTheirOwnCap() {
        let half = TrainerTarget(kind: .race, name: "Meia", distanceMeters: 21_097.5)

        #expect(TrainerEngine.longCap(for: half) == 22_000)
        #expect(max(TrainerEngine.longCap(for: half), TrainerEngine.volumeLongCap(for: half, weekMeters: 80_000, longPace: 315)) == 22_000)
    }
}
