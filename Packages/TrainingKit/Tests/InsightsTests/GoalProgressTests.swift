import FITReader
import Foundation
import Metrics
import Storage
import Testing
import TrainingCore
@testable import Insights

@Suite struct GoalProgressTests {
    private let speed = 1_000 / 285.0

    private func steady(from start: Double, meters: Double, startMeters: Double) -> [FITSample] {
        (1...Int(meters / speed)).map { FITSample(t: start + Double($0), distance: startMeters + Double($0) * speed) }
    }

    private func withStop(at stopMeters: Double, seconds: Int, total: Double) -> [FITSample] {
        let first = steady(from: 0, meters: stopMeters, startMeters: 0)
        let stopAt = first.last!.t
        let stopped = (1...seconds).map { FITSample(t: stopAt + Double($0), distance: stopMeters) }
        return [FITSample(t: 0, distance: 0)] + first + stopped + steady(from: stopAt + Double(seconds), meters: total - stopMeters, startMeters: stopMeters)
    }

    private func run(_ id: Int64, _ day: String, meters: Double, seconds: Double, samples: [FITSample]? = nil) -> ActivityRecord {
        ActivityRecord(
            activityId: id, typeKey: "running", name: "Corrida", start: ISO8601DateFormatter().date(from: "\(day)T10:00:00Z")!, distance: meters, duration: seconds,
            samplesData: samples.map { try! JSONEncoder().encode($0) }, localDay: day
        )
    }

    private let created = Day(iso: "2026-10-01")!

    @Test func longGoalCountsLastLongRunsAndLongestStretch() {
        let goal = GoalRecord(kind: .continuousLong, distanceKm: 16, paceSecondsPerKm: 290)
        let runs = [
            run(1, "2026-10-20", meters: 15_000, seconds: 4_300),
            run(2, "2026-11-01", meters: 16_100, seconds: 4_600, samples: withStop(at: 10_600, seconds: 30, total: 16_100)),
            run(3, "2026-11-08", meters: 9_000, seconds: 2_600),
            run(4, "2026-11-12", meters: 16_200, seconds: 4_630, samples: [FITSample(t: 0, distance: 0)] + steady(from: 0, meters: 16_200, startMeters: 0)),
        ]

        let candidates = longGoalCandidates(goal, runs: runs)
        let progress = longGoalProgress(goal, runs: candidates, createdOn: created)

        #expect(candidates.map(\.activityId) == [4, 2, 1])
        #expect(progress.runs.map(\.activityId) == [1, 2, 4])
        #expect(progress.runs.map(\.met) == [nil, false, true])
        #expect(progress.metCount == 1)
        #expect(abs((progress.bestContinuousKm ?? 0) - 16.2) < 0.05)
        #expect(progress.achievedOn == Day(iso: "2026-11-12"))
    }

    @Test func timeGoalReportsGapAndAchievedRace() {
        let goal = GoalRecord(kind: .time, distanceKm: 10, targetSeconds: 2_400, deadline: "2027-03-15")
        let today = Day(iso: "2026-11-14")!
        let efforts = (0..<20).map { Effort(distance: 5_000, seconds: 1_260 - Double($0) * 2, day: today.adding(days: -$0 * 4), kind: .split5k) }

        let open = timeGoalProgress(goal, efforts: efforts, runs: [], createdOn: created, today: today)
        #expect(open.todaySeconds != nil)
        #expect(abs((open.gapSeconds ?? 0) - ((open.todaySeconds ?? 0) - 2_400)) < 0.001)
        #expect(open.achievedOn == nil)

        let done = timeGoalProgress(goal, efforts: efforts, runs: [run(9, "2026-11-10", meters: 10_020, seconds: 2_395)], createdOn: created, today: today)
        #expect(done.achievedOn == Day(iso: "2026-11-10"))
    }
}
