import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerVolumeTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var history: TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(run(base + 1, start, km: 12, pace: 340, kind: .easy))
            runs.append(run(base + 2, start.adding(days: 1), km: 12, pace: 262, kind: .tempo))
            runs.append(run(base + 3, start.adding(days: 3), km: 12, pace: 340, kind: .easy))
            runs.append(run(base + 4, start.adding(days: 5), km: 20, pace: 335, kind: .long))
        }
        return TrainerHistory(runs: runs, predictions: [10_000: 2_580, 5_000: 1_230])
    }

    private func run(_ id: Int64, _ day: Day, km: Double, pace: Double, kind: RunKind) -> TrainerRun {
        TrainerRun(activityId: id, day: day, meters: km * 1_000, seconds: km * pace, kind: kind)
    }

    private func race(weeks: Int, meters: Double = 21_097.5) -> TrainerTarget {
        TrainerTarget(kind: .race, name: "Prova", date: monday.adding(days: (weeks - 1) * 7 + 5), distanceMeters: meters, goalSeconds: 5_700)
    }

    private func plan(target: TrainerTarget, start: Double = 60_000, peak: Double = 78_000) -> TrainerPlan {
        TrainerEngine.create(
            target: target, structure: TrainerEngine.defaultStructure, strength: [], history: history, today: monday, now: now,
            startMeters: start, peakMeters: peak
        )
    }

    private func km(_ plan: TrainerPlan) -> [Int] { plan.weeks.map { Int($0.targetMeters / 1_000) } }

    @Test func datedPlanRisesFivePercentRecoversEveryFourthWeekAndTapers() {
        let plan = plan(target: race(weeks: 16))

        #expect(plan.weeks.count == 16)
        #expect(km(plan) == [60, 63, 66, 53, 66, 69, 70, 56, 70, 74, 78, 62, 78, 78, 55, 39])
        #expect([3, 7, 11].allSatisfy { plan.weeks[$0].isRecovery })
        #expect(plan.weeks.filter(\.isRecovery).count == 3)
        #expect(plan.weeks.filter { $0.phase == .taper }.map(\.targetMeters) == [55_000, 39_000])
    }

    @Test func peakHappensOnlyInTheSpecificPhase() {
        let plan = plan(target: race(weeks: 16), start: 60_000, peak: 66_000)
        let reached = plan.weeks.filter { $0.targetMeters == 66_000 }

        #expect(plan.weeks.prefix { $0.phase != .specific }.allSatisfy { $0.targetMeters < 66_000 })
        #expect(reached.contains { $0.phase == .specific })
    }

    @Test func shortDeadlineDoesNotReachThePeakAndTheLongRunSaysSo() throws {
        let plan = plan(target: race(weeks: 6))
        let longs = plan.workouts.filter { $0.kind == .long }

        #expect(plan.weeks.filter { $0.phase != .taper }.map(\.targetMeters).max() == 66_000)
        #expect(!longs.isEmpty)
        #expect(longs.first?.rationale.contains("O tempo até a prova não dá para chegar aos 78 km com segurança; o pico fica em 66 km.") == true)
    }

    @Test func reachablePeakHasNoWarning() {
        let plan = plan(target: race(weeks: 16))

        #expect(plan.workouts.allSatisfy { !$0.rationale.contains("não dá para chegar") })
    }

    @Test func textGoalWithDeadlineBehavesLikeARace() {
        let deadline = race(weeks: 16).date
        let text = TrainerTarget(kind: .text, name: "Correr forte", date: deadline, text: "Correr forte")
        let textual = plan(target: text)
        let dated = plan(target: race(weeks: 16))

        #expect(km(textual) == km(dated))
        #expect(textual.weeks.map(\.phase) == dated.weeks.map(\.phase))
    }

    @Test func openGoalReachesThePeakThenHoldsThreePlusOneWithoutTaper() {
        let open = TrainerTarget(kind: .text, name: "Correr mais", text: "Correr mais")
        let plan = plan(target: open)

        #expect(plan.weeks.count == 12)
        #expect(km(plan) == [60, 63, 66, 53, 66, 69, 72, 58, 72, 76, 78, 62])
        #expect(plan.weeks.allSatisfy { $0.phase != .taper })
    }

    @Test func openGoalHoldsThreePlusOneAtThePeak() {
        let open = TrainerTarget(kind: .text, name: "Correr mais", text: "Correr mais")

        #expect(km(plan(target: open, start: 70_000, peak: 72_000)) == [70, 72, 72, 58, 72, 72, 72, 58, 72, 72, 72, 58])
    }

    @Test func openGoalStagesRestartAtTheStartOfACycleAfterReachingTheTop() throws {
        let context = TrainerSkeletonContext(total: 24, taperWeeks: 0, openEnded: true, longCap: 22_000, peakVolume: 72_000)
        let state = TrainerSkeletonState(volume: 70_000, long: 16_000, stage: 0, weeksAtStage: 0, started: false)

        let weeks = TrainerEngine.buildWeeks(
            context: context, firstIndex: 1, firstStart: monday, state: state, adjustment: TrainerSkeletonAdjustment()
        )

        let top = TrainerEngineConstants.thresholdBlocks.last.map(TrainerEngineText.stageLabel)
        let first = TrainerEngineConstants.thresholdBlocks.first.map(TrainerEngineText.stageLabel)
        let topIndex = weeks.firstIndex { $0.thresholdFocus == top }
        let restart = weeks.firstIndex { $0.index > 9 && $0.thresholdFocus == first && !$0.isRecovery }
        let topAt = try #require(topIndex)
        let restartAt = try #require(restart)
        #expect(restartAt > topAt)
        #expect(restartAt % 4 == 0)
    }

    @Test func oldPlanMigratesToStartAndPeak() throws {
        let plan = plan(target: race(weeks: 16), start: 50_000, peak: 60_000)
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        object["startMeters"] = nil
        object["peakMeters"] = nil
        object["weeklyMeters"] = 50_000

        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: JSONSerialization.data(withJSONObject: object))

        #expect(decoded.startMeters == 50_000)
        #expect(decoded.peakMeters == 55_000)
    }

    @Test func peakDefaultsToQuarterAboveStart() {
        let plan = plan(target: race(weeks: 16), start: 60_000, peak: 0)

        #expect(plan.weeks.map(\.targetMeters).max() == 60_000)
        let defaulted = TrainerEngine.create(
            target: race(weeks: 16), structure: TrainerEngine.defaultStructure, strength: [], history: history, today: monday, now: now,
            startMeters: 60_000
        )
        #expect(defaulted.weeks.filter { $0.phase != .taper }.map(\.targetMeters).max() == 75_000)
    }

    @Test func weeksToPeakCountsTheRecoveryWeeks() {
        #expect(TrainerEngine.weeksToPeak(startMeters: 60_000, peakMeters: 78_000) == 11)
        #expect(TrainerEngine.weeksToPeak(startMeters: 60_000, peakMeters: 60_000) == 1)
    }
}
