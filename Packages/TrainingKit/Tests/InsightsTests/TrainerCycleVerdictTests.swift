import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct TrainerCycleVerdictTests {
    private func review(_ plan: TrainerPlan, _ history: TrainerHistory) throws -> TrainerCycleReview {
        try #require(TrainerEngine.cycleReview(plan: plan, history: history, today: raceDay.adding(days: 1)))
    }

    @Test func fullVolumeStableReadinessAndBetterFormIncrease() throws {
        let plan = makePlan()
        let result = try review(plan, history(plan, done: 0.97))
        #expect(result.verdict == .increase)
        #expect(result.suggestedPeakMeters == 86_000)
        #expect(result.suggestedStartMeters == 64_000)
    }

    @Test func partialVolumeKeeps() throws {
        let plan = makePlan()
        let result = try review(plan, history(plan, done: 0.85))
        #expect(result.verdict == .keep)
        #expect(result.suggestedPeakMeters == result.currentPeakMeters)
        #expect(result.suggestedStartMeters == result.currentStartMeters)
    }

    @Test func lowVolumeDecreases() throws {
        let plan = makePlan()
        let result = try review(plan, history(plan, done: 0.7))
        #expect(result.verdict == .decrease)
        #expect(result.suggestedPeakMeters == 72_000)
        #expect(result.suggestedStartMeters == 54_000)
    }

    @Test func readinessDropDecreasesEvenWithFullVolume() throws {
        let plan = makePlan()
        let result = try review(plan, history(plan, done: 1.0, readinessDrop: 14))
        #expect(result.verdict == .decrease)
        #expect(result.reasons.contains { if case .readiness = $0 { true } else { false } })
    }

    @Test func twoExtraLightWeeksDecrease() throws {
        var plan = makePlan()
        plan.lightWeeks = [plan.weeks[2].start, plan.weeks[6].start]
        let result = try review(plan, history(plan, done: 1.0))
        #expect(result.verdict == .decrease)
    }

    @Test func shortCycleKeepsWithTooShortReason() throws {
        var plan = makePlan()
        plan.endedOn = monday.adding(days: 7 * 3 + 1)
        let result = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan, done: 1.0), today: plan.endedOn!))
        #expect(result.verdict == .keep)
        #expect(result.reasons == [.tooShort(weeks: 3)])
    }

    @Test func noReadinessDataStillIncreases() throws {
        let plan = makePlan()
        let result = try review(plan, history(plan, done: 0.97, readiness: false))
        #expect(result.verdict == .increase)
    }

    @Test func fullVolumeWithoutPredictionGainKeepsWithNoProgress() throws {
        let plan = makePlan()
        var flat = history(plan, done: 1.0)
        for day in flat.predictionSeries.keys { flat.predictionSeries[day] = [10_000: 2_460] }
        let result = try review(plan, flat)
        #expect(result.verdict == .keep)
        #expect(result.reasons.contains(.noProgress))
    }

    @Test func reasonsAreCappedAtThree() throws {
        let plan = makePlan()
        let result = try review(plan, history(plan, done: 0.97, raceSeconds: 5_628))
        #expect(result.reasons.count <= 3)
        guard case .volume = result.reasons.first else { Issue.record("first reason must be volume"); return }
    }
}
