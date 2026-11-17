import Foundation
@testable import Insights
import Testing
import TrainingCore

@Suite struct TrainerTimeEstimateTests {
    private let day = Day(year: 2026, month: 11, day: 17)

    @Test func thresholdSumsEachStepAndTheRests() throws {
        let workout = TrainerWorkout(
            day: day, kind: .threshold, title: "Limiar", totalMeters: 9_500,
            steps: [
                TrainerStep(kind: .warmup, meters: 2_000, paceLow: 360, paceHigh: 390),
                TrainerStep(kind: .work, repeats: 4, meters: 1_500, paceLow: 290, paceHigh: 300),
                TrainerStep(kind: .recovery, repeats: 3, meters: 0, restSeconds: 90),
            ],
            rationale: ""
        )
        let range = try #require(TrainerEngine.timeEstimate(workout, fallback: nil))
        #expect(range.fastest == 720 + 1_740 + 270 + 540)
        #expect(range.slowest == 780 + 1_800 + 270 + 585)
        #expect(range.approximate == false)
    }

    @Test func steadyRunUsesTheWorkoutPace() throws {
        let workout = TrainerWorkout(
            day: day, kind: .long, title: "Longão", totalMeters: 18_000,
            steps: [TrainerStep(kind: .steady, meters: 18_000, paceLow: 350, paceHigh: 380)], rationale: ""
        )
        let range = try #require(TrainerEngine.timeEstimate(workout, fallback: nil))
        #expect(range.fastest == 6_300)
        #expect(range.slowest == 6_840)
    }

    @Test func stepWithoutPaceUsesTheFallbackAndIsApproximate() throws {
        let workout = TrainerWorkout(
            day: day, kind: .vo2max, title: "Subidas", totalMeters: 2_400,
            steps: [TrainerStep(kind: .work, repeats: 6, meters: 200), TrainerStep(kind: .recovery, repeats: 5, meters: 200)],
            rationale: ""
        )
        #expect(TrainerEngine.timeEstimate(workout, fallback: nil) == nil)
        let range = try #require(TrainerEngine.timeEstimate(workout, fallback: PaceBand(fastest: 360, slowest: 390)))
        #expect(range.approximate)
        #expect(abs(range.fastest - 2.4 * 360) < 0.001)
    }

    @Test func restDayHasNoEstimate() {
        let workout = TrainerWorkout(day: day, kind: .off, title: "Descanso", totalMeters: 0, steps: [], rationale: "")
        #expect(TrainerEngine.timeEstimate(workout, fallback: nil) == nil)
    }

    @Test func fallbackNeedsRecentRuns() {
        let empty = TrainerHistory(runs: [])
        #expect(TrainerEngine.easyPaceBand(plan: nil, history: empty, today: day) == nil)
        let runs = TrainerHistory(runs: [TrainerRun(activityId: 1, day: day.adding(days: -3), meters: 8_000, seconds: 8 * 375, kind: .easy)])
        #expect(TrainerEngine.easyPaceBand(plan: nil, history: runs, today: day) == PaceBand(fastest: 368, slowest: 382))
    }
}
