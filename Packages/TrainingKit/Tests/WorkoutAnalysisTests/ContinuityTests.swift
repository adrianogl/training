import FITReader
import Testing
@testable import WorkoutAnalysis

@Suite struct ContinuityTests {
    private func steady(from start: Double, meters: Double, speed: Double, startMeters: Double) -> [FITSample] {
        let seconds = Int(meters / speed)
        return (1...seconds).map { FITSample(t: start + Double($0), distance: startMeters + Double($0) * speed) }
    }

    @Test func runWithoutStopsMeetsTheGoal() throws {
        let samples = [FITSample(t: 0, distance: 0)] + steady(from: 0, meters: 16_000, speed: 1_000 / 285, startMeters: 0)

        let continuity = try #require(runContinuity(samples))

        #expect(continuity.pauses.isEmpty)
        #expect(abs(continuity.longestContinuousMeters - 16_000) < 5)
        #expect(continuity.meetsContinuousGoal(distanceKm: 16, paceSecondsPerKm: 290))
        #expect(!continuity.meetsContinuousGoal(distanceKm: 16, paceSecondsPerKm: 280))
    }

    @Test func stoppingWithoutAutoPauseCountsAsAPause() throws {
        let speed = 1_000 / 285.0
        let first = steady(from: 0, meters: 11_800, speed: speed, startMeters: 0)
        let stopAt = first.last!.t
        let stopped = (1...38).map { FITSample(t: stopAt + Double($0), distance: 11_800) }
        let second = steady(from: stopAt + 38, meters: 4_200, speed: speed, startMeters: 11_800)

        let continuity = try #require(runContinuity([FITSample(t: 0, distance: 0)] + first + stopped + second))

        #expect(continuity.pauses.count == 1)
        #expect(abs(continuity.pauses[0].startMeters - 11_800) < 5)
        #expect(continuity.pauses[0].seconds == 38)
        #expect(abs(continuity.longestContinuousMeters - 11_800) < 5)
        #expect(!continuity.meetsContinuousGoal(distanceKm: 16, paceSecondsPerKm: 290))
    }

    @Test func autoPauseGapCountsAndShortSlowdownDoesNot() throws {
        let speed = 1_000 / 285.0
        let first = steady(from: 0, meters: 5_000, speed: speed, startMeters: 0)
        let gapEnd = first.last!.t + 40
        let afterGap = steady(from: gapEnd, meters: 3_000, speed: speed, startMeters: 5_000)
        let slowStart = afterGap.last!.t
        let slowdown = (1...6).map { FITSample(t: slowStart + Double($0), distance: 8_000 + Double($0) * 0.2) }
        let end = steady(from: slowStart + 6, meters: 2_000, speed: speed, startMeters: 8_001.2)

        let continuity = try #require(runContinuity([FITSample(t: 0, distance: 0)] + first + afterGap + slowdown + end))

        #expect(continuity.pauses.count == 1)
        #expect(continuity.pauses[0].seconds >= 40)
        #expect(abs(continuity.longestContinuousMeters - 5_000) < 5)
    }

    @Test func samplesWithoutDistanceGiveNothing() {
        #expect(runContinuity([FITSample(t: 0, heartRate: 120), FITSample(t: 1, heartRate: 121)]) == nil)
    }
}
