import FITReader
import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerZoneTrendTests {
    private let today = Day(year: 2026, month: 11, day: 26)

    private func block(
        _ kind: BlockKind, start: Double, seconds: Double, meters: Double, heartRate: Int = 150, prescribed: PrescribedStep? = nil
    ) -> WorkoutBlock {
        let lap = LapSummary(startOffset: start, timerSeconds: seconds, distance: meters, avgSpeed: meters / seconds, avgHeartRate: heartRate)
        return WorkoutBlock(
            kind: kind, ordinal: 1, label: "", prescribed: prescribed, laps: [lap], seconds: seconds, distance: meters,
            avgSpeed: meters / seconds, avgHeartRate: heartRate, maxHeartRate: heartRate, dominantZone: nil, status: .noTarget
        )
    }

    private func speed(_ pace: Double) -> Double { 1_000 / pace }

    private func step(meters: Double, pace: Double, intensity: StepIntensity = .active) -> PrescribedStep {
        PrescribedStep(index: 0, intensity: intensity, duration: .distance(meters: meters), target: .speed(low: speed(pace + 3), high: speed(pace - 3)))
    }

    private func samples(from start: Double, to end: Double, heartRate: (Double) -> Int) -> [FITSample] {
        stride(from: start, to: end, by: 1).map { FITSample(t: $0, heartRate: heartRate($0)) }
    }

    private var history: TrainerHistory {
        let runs = (0..<4).map { offset in
            TrainerRun(
                activityId: Int64(offset), day: today.adding(days: -offset * 7 - 1), meters: 10_000, seconds: 2_800, kind: .tempo,
                workPaceSeconds: 253
            )
        }
        let easy = (0..<6).map { offset in
            TrainerRun(activityId: Int64(100 + offset), day: today.adding(days: -offset * 5 - 2), meters: 10_000, seconds: 3_100, kind: .easy)
        }
        return TrainerHistory(runs: runs + easy)
    }

    @Test func goalThresholdIsTheFifteenKmEquivalentOfTheGoal() throws {
        let target = TrainerTarget(kind: .race, name: "Meia", distanceMeters: 21_097.5, goalSeconds: 5_700)
        let expected = 5_700 * pow(15_000 / 21_097.5, 1.06) / 15
        let value = try #require(TrainerZoneTrends.goalThreshold(target))

        #expect(abs(value - expected) < 0.01)
        #expect(TrainerZoneTrends.goalThreshold(TrainerTarget(kind: .text, name: "Aberto")) == nil)
    }

    @Test func blocksLandInTheZoneOfTheirTarget() throws {
        let threshold = TrainerZoneTrendRun(
            day: today.adding(days: -1), kind: .tempo,
            blocks: [
                block(.warmup, start: 0, seconds: 900, meters: 3_000, heartRate: 140),
                block(.active, start: 900, seconds: 500, meters: 2_000, prescribed: step(meters: 2_000, pace: 248)),
                block(.recovery, start: 1_400, seconds: 90, meters: 0, prescribed: PrescribedStep(index: 1, intensity: .rest, duration: .time(seconds: 90), target: .open)),
                block(.active, start: 1_490, seconds: 500, meters: 2_000, prescribed: step(meters: 2_000, pace: 248)),
                block(.cooldown, start: 1_990, seconds: 330, meters: 1_000, heartRate: 135),
            ],
            samples: samples(from: 0, to: 2_320) { t in (900..<960).contains(t) || (1_490..<1_550).contains(t) ? 130 : 162 }
        )
        let vo2 = TrainerZoneTrendRun(
            day: today.adding(days: -3), kind: .intervals,
            blocks: [
                block(.active, start: 0, seconds: 230, meters: 1_000, heartRate: 170, prescribed: step(meters: 1_000, pace: 230)),
                block(.active, start: 400, seconds: 42, meters: 200, heartRate: 175, prescribed: step(meters: 200, pace: 220)),
            ]
        )
        let easy = TrainerZoneTrendRun(
            day: today.adding(days: -2), kind: .easy,
            blocks: [block(.active, start: 0, seconds: 300, meters: 1_000, heartRate: 145), block(.active, start: 300, seconds: 302, meters: 1_000, heartRate: 147)]
        )
        let trend = TrainerZoneTrends.build(
            history: history, runs: [threshold, vo2, easy], target: nil, overrides: [:], thresholdHeartRates: [today: 165], maxHeartRate: 190,
            today: today
        )
        let week = try #require(trend.weeks.last)

        #expect(trend.weeks.count == 12)
        #expect(week.actual[4]?.pace == 250)
        #expect(week.actual[4]?.heartRate == 162)
        #expect(week.actual[5]?.pace == 230)
        #expect(week.actual[2]?.pace == 301)
        #expect(week.actual[1]?.pace == 330)
        #expect(week.actual[1]?.heartRate == 162)
        #expect(week.actual[3] == nil)
        #expect(trend.weeks.first?.actual.isEmpty == true)
        #expect(trend.averages[4]?.pace == 250)
    }

    @Test func slowTrotKeepsOnlyTheHeartRate() throws {
        let run = TrainerZoneTrendRun(
            day: today, kind: .intervals,
            blocks: [block(.recovery, start: 0, seconds: 300, meters: 400, heartRate: 128)]
        )
        let trend = TrainerZoneTrends.build(
            history: history, runs: [run], target: nil, overrides: [:], thresholdHeartRates: [:], maxHeartRate: nil, today: today
        )
        let actual = try #require(trend.weeks.last?.actual[1])

        #expect(actual.pace == nil)
        #expect(actual.heartRate == 128)
    }

    @Test func weeklyTargetsFollowThePlanRulesOfThatWeek() throws {
        let trend = TrainerZoneTrends.build(
            history: history, runs: [], target: nil, overrides: [.threshold: 240], thresholdHeartRates: [today: 170], maxHeartRate: 190, today: today
        )
        let week = try #require(trend.weeks.last)
        let z4 = try #require(week.target(4))
        let z1 = try #require(week.target(1))
        let z5 = try #require(week.target(5))

        #expect(week.threshold == 240)
        #expect(z4.paceLow == 232 && z4.paceHigh == 243)
        #expect(z1.paceLow == week.target(2)?.paceHigh && z1.paceHigh == nil)
        #expect(z1.heartRateLow == nil && z1.heartRateHigh == 144)
        #expect(z5.heartRateLow == 173 && z5.heartRateHigh == nil)
    }

    @Test func historyCoversThePaceWindowOfTheFirstWeek() {
        #expect(TrainerZoneTrends.weekStarts(today: today).first == Day(year: 2026, month: 9, day: 7))
        #expect(TrainerZoneTrends.historyStart(today: today) == Day(year: 2026, month: 6, day: 9))
    }

    @Test func thresholdChangeComparesSixWeeksBefore() {
        let weeks = (0..<12).map { index in
            TrainerZoneWeek(start: today.adding(days: (index - 11) * 7), threshold: 260 - Double(index), targets: [], actual: [:])
        }
        let trend = TrainerZoneTrend(weeks: weeks, goalThreshold: nil, averages: [:])

        #expect(TrainerZoneTrends.thresholdChange(trend, at: 11) == -6)
        #expect(TrainerZoneTrends.thresholdChange(trend, at: 5) == nil)
    }

    @Test func fitSaysHowFarOutsideTheTarget() {
        let target = TrainerZoneTarget(zone: 4, paceLow: 245, paceHigh: 256, heartRateLow: 157, heartRateHigh: 167)
        let open = TrainerZoneTarget(zone: 1, paceLow: 303, paceHigh: nil, heartRateLow: nil, heartRateHigh: 139)

        #expect(TrainerZoneTrends.paceFit(262, target: target) == .slower(6))
        #expect(TrainerZoneTrends.paceFit(242, target: target) == .faster(3))
        #expect(TrainerZoneTrends.paceFit(250, target: target) == .inside)
        #expect(TrainerZoneTrends.paceFit(400, target: open) == .inside)
        #expect(TrainerZoneTrends.heartRateFit(170, target: target) == .above(3))
        #expect(TrainerZoneTrends.heartRateFit(155, target: target) == .below(2))
        #expect(TrainerZoneTrends.heartRateFit(100, target: open) == .inside)
    }
}
