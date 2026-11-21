import GarminAPI
import Metrics
import Testing
@testable import trAIning

@Suite struct PlanAdjustTests {
    private func plan(_ title: String, meters: Double, steps: [PlannedStep]) -> PlannedWorkout {
        PlannedWorkout(id: 1, day: "2026-11-20", title: title, estimatedSeconds: nil, estimatedMeters: meters, steps: steps)
    }

    private let easy = PlannedStep(kind: .active, meters: 8_000, target: .zone(2))

    @Test func singleContinuousStepIsContinuous() {
        #expect(PlanText.shape(plan("Corrida fácil", meters: 8_000, steps: [easy])) == .continuous)
    }

    @Test func warmupAndCooldownAroundOneBlockIsContinuous() {
        let steps = [PlannedStep(kind: .warmup, meters: 2_000), PlannedStep(kind: .active, meters: 6_000, target: .zone(3)), PlannedStep(kind: .cooldown, meters: 1_000)]
        #expect(PlanText.shape(plan("Ritmo 6 km", meters: 9_000, steps: steps)) == .continuous)
    }

    @Test func repeatIsIntervals() {
        let repeatStep = PlannedStep(kind: .other, repeats: 5, children: [PlannedStep(kind: .active, meters: 1_000), PlannedStep(kind: .recovery, meters: 400)])
        let steps = [PlannedStep(kind: .warmup, meters: 2_000), repeatStep, PlannedStep(kind: .cooldown, meters: 1_000)]
        #expect(PlanText.shape(plan("Limiar 5 × 1 km", meters: 10_000, steps: steps)) == .intervals)
    }

    @Test func twoActiveBlocksWithoutRepeatIsIntervals() {
        let steps = [PlannedStep(kind: .active, meters: 3_000), PlannedStep(kind: .recovery, meters: 400), PlannedStep(kind: .active, meters: 3_000)]
        #expect(PlanText.shape(plan("Ritmo 2 × 3 km", meters: 6_400, steps: steps)) == .intervals)
    }

    @Test func longTitleOrDistanceIsLong() {
        #expect(PlanText.shape(plan("Longão 18 km", meters: 18_000, steps: [easy])) == .long)
        #expect(PlanText.shape(plan("Corrida 16 km", meters: 16_000, steps: [easy])) == .long)
    }

    @Test func longWithRepeatsStaysIntervals() {
        let repeatStep = PlannedStep(kind: .other, repeats: 3, children: [PlannedStep(kind: .active, meters: 2_000), PlannedStep(kind: .recovery, meters: 1_000)])
        #expect(PlanText.shape(plan("Longão 20 km com 3 × 2 km", meters: 20_000, steps: [easy, repeatStep])) == .intervals)
    }
}
