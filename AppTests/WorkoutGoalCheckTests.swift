import FITReader
import Foundation
import Storage
import Testing
import WorkoutAnalysis
@testable import trAIning

@Suite struct WorkoutGoalCheckTests {
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

    private func run(_ id: Int64, day: String, meters: Double, seconds: Double, samples: [FITSample]? = nil) -> ActivityRecord {
        ActivityRecord(
            activityId: id, typeKey: "running", name: "Corrida", start: ISO8601DateFormatter().date(from: "\(day)T10:00:00Z")!, distance: meters, duration: seconds,
            samplesData: samples.map { try! JSONEncoder().encode($0) }, localDay: day
        )
    }

    private func block(_ kind: BlockKind, meters: Double, seconds: Double) -> WorkoutBlock {
        WorkoutBlock(kind: kind, ordinal: 0, label: "", prescribed: nil, laps: [], seconds: seconds, distance: meters, avgSpeed: meters / seconds, avgHeartRate: nil, maxHeartRate: nil, dominantZone: nil, status: .noTarget)
    }

    @Test func longRunWithAStopShowsWhereAndComparesWithThePreviousOne() {
        let goal = GoalRecord(kind: .continuousLong, distanceKm: 16, paceSecondsPerKm: 290)
        let previous = run(1, day: "2026-11-01", meters: 16_100, seconds: 4_600, samples: withStop(at: 10_600, seconds: 30, total: 16_100))
        let current = run(2, day: "2026-11-08", meters: 16_000, seconds: 4_600, samples: withStop(at: 11_800, seconds: 38, total: 16_000))

        let entries = WorkoutGoalCheck.entries(record: current, runs: [current, previous], blocks: [], goals: [goal])

        let entry = try! #require(entries.first)
        #expect(entry.status == "1 pausa")
        #expect(!entry.good)
        #expect(entry.lines.contains("Pausa de 38 s no km 11,8."))
        #expect(entry.lines.contains("Maior trecho sem parar: 11,8 km (no longão anterior: 10,6 km)."))
    }

    @Test func longRunWithoutStopsMeetsTheGoal() {
        let goal = GoalRecord(kind: .continuousLong, distanceKm: 16, paceSecondsPerKm: 290)
        let current = run(3, day: "2026-11-12", meters: 16_200, seconds: 4_620, samples: [FITSample(t: 0, distance: 0)] + steady(from: 0, meters: 16_200, startMeters: 0))

        let entry = WorkoutGoalCheck.entries(record: current, runs: [current], blocks: [], goals: [goal]).first

        #expect(entry?.status == "cumprida")
        #expect(entry?.good == true)
    }

    @Test func intervalsCompareActiveBlocksWithTheGoalPace() {
        let goal = GoalRecord(kind: .time, distanceKm: 10, targetSeconds: 2_400)
        let current = run(4, day: "2026-11-10", meters: 9_800, seconds: 3_300)
        let blocks = [block(.warmup, meters: 2_500, seconds: 840), block(.active, meters: 1_000, seconds: 238), block(.recovery, meters: 300, seconds: 120), block(.active, meters: 1_000, seconds: 238)]

        let entry = WorkoutGoalCheck.entries(record: current, runs: [current], blocks: blocks, goals: [goal]).first

        #expect(entry?.lines.first == "Blocos fortes a 3:58/km, 2 s/km mais rápido que o pace da meta (4:00/km).")
        #expect(entry?.good == true)
    }

    @Test func raceAtTheGoalDistanceComparesTheTime() {
        let goal = GoalRecord(kind: .time, distanceKm: 10, targetSeconds: 2_400)
        let current = run(5, day: "2026-11-11", meters: 10_050, seconds: 2_450)

        let entry = WorkoutGoalCheck.entries(record: current, runs: [current], blocks: [], goals: [goal]).first

        #expect(entry?.status == "ainda não")
        #expect(entry?.lines.first?.hasPrefix("10 km em 40:38") == true)
    }
}
