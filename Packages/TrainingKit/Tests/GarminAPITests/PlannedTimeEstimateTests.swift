import Foundation
@testable import GarminAPI
import Testing
import TrainingCore

@Suite struct PlannedTimeEstimateTests {
    private let intervals = PlannedWorkout(
        id: 1, day: "2026-11-18", title: "Intervalado 8 × 400 m", estimatedSeconds: 2_700, estimatedMeters: 6_400,
        steps: [
            PlannedStep(kind: .warmup, seconds: 900),
            PlannedStep(kind: .other, repeats: 8, children: [
                PlannedStep(kind: .active, meters: 400, target: .pace(fastest: 250, slowest: 260)),
                PlannedStep(kind: .recovery, seconds: 60),
            ]),
            PlannedStep(kind: .cooldown, seconds: 600),
        ]
    )

    @Test func intervalsAddTimedStepsAndPacedDistances() throws {
        let range = try #require(PlannedTimeEstimate.total(intervals, fallback: nil))
        #expect(range.fastest == 900 + 800 + 480 + 600)
        #expect(range.slowest == 900 + 832 + 480 + 600)
        #expect(range.approximate == false)
    }

    @Test func heartRateTargetUsesTheFallback() throws {
        let easy = PlannedWorkout(id: 2, day: "2026-11-20", title: "Rodagem Z2", estimatedSeconds: nil, estimatedMeters: 8_000,
                                  steps: [PlannedStep(kind: .active, meters: 8_000, target: .zone(2))])
        #expect(PlannedTimeEstimate.total(easy, fallback: nil) == nil)
        let range = try #require(PlannedTimeEstimate.total(easy, fallback: PaceBand(fastest: 360, slowest: 390)))
        #expect(range == RunTimeRange(fastest: 2_880, slowest: 3_120, approximate: true))
    }

    @Test func openStepMarksTheEstimateApproximate() throws {
        let plan = PlannedWorkout(id: 3, day: "2026-11-21", title: "Livre", estimatedSeconds: nil, estimatedMeters: nil,
                                  steps: [PlannedStep(kind: .warmup), PlannedStep(kind: .active, seconds: 1_200)])
        #expect(try #require(PlannedTimeEstimate.total(plan, fallback: nil)).approximate)
    }

    @Test func singleStepNeedsDistanceAndPace() {
        #expect(PlannedTimeEstimate.single(PlannedStep(kind: .active, meters: 400, target: .pace(fastest: 250, slowest: 260))) == RunTimeRange(fastest: 100, slowest: 104))
        #expect(PlannedTimeEstimate.single(PlannedStep(kind: .recovery, seconds: 60)) == nil)
        #expect(PlannedTimeEstimate.single(PlannedStep(kind: .active, meters: 400, target: .zone(4))) == nil)
    }
}
