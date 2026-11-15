import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerCycleTests {
    @Test func oldPlanJsonDecodesWithoutEndedOn() throws {
        var plan = makePlan()
        plan.endedOn = nil
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: data)
        #expect(decoded.endedOn == nil)
    }

    @Test func endedOnRoundTrips() throws {
        var plan = makePlan()
        plan.endedOn = Day(year: 2026, month: 11, day: 12)
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: JSONEncoder().encode(plan))
        #expect(decoded.endedOn == Day(year: 2026, month: 11, day: 12))
    }

    @Test func datedPlanHasNoReviewBeforeRaceDay() {
        let plan = makePlan()
        #expect(TrainerEngine.cycleReview(plan: plan, history: history(plan), today: raceDay.adding(days: -1)) == nil)
    }

    @Test func datedPlanReviewsEveryWeekAfterTheRace() throws {
        let plan = makePlan()
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan, done: 1.0), today: raceDay.adding(days: 1)))
        #expect(review.weeks.count == plan.weeks.count)
        #expect(review.endedEarly == false)
        #expect(review.first == plan.weeks.first?.start)
    }

    @Test func raceRunOnRaceDayClosesTheCycleThatDay() throws {
        let plan = makePlan()
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan, done: 1.0, raceSeconds: 5_628), today: raceDay))
        #expect(review.raceSeconds == 5_628)
        #expect(review.goalSeconds == 5_700)
    }

    @Test func endingEarlyKeepsOnlyFinishedWeeks() throws {
        var plan = makePlan()
        plan.endedOn = monday.adding(days: 7 * 5 + 2)
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan, done: 1.0), today: plan.endedOn!))
        #expect(review.weeks.map(\.index) == Array(plan.weeks.prefix(5).map(\.index)))
        #expect(review.endedEarly)
    }

    @Test func endingInTheFirstWeekGivesAnEmptyReview() throws {
        var plan = makePlan()
        plan.endedOn = monday.adding(days: 2)
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan), today: plan.endedOn!))
        #expect(review.weeks.isEmpty)
        #expect(review.doneShare == 0)
    }

    @Test func openPlanReviewsTheLatestClosedTwelveWeekBlock() throws {
        let plan = makeOpenPlan(weeks: 26)
        #expect(plan.weeks.count == 26)
        let today = monday.adding(days: 7 * 25)
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan, done: 1.0), today: today))
        #expect(review.first == monday.adding(days: 7 * 12))
        #expect(review.weeks.count == 12)
    }

    @Test func openPlanHasNoReviewBeforeTwelveWeeks() {
        let plan = makeOpenPlan(weeks: 12)
        #expect(TrainerEngine.cycleReview(plan: plan, history: history(plan), today: monday.adding(days: 7 * 11 + 3)) == nil)
    }

    @Test func missingReadinessLeavesAveragesEmpty() throws {
        let plan = makePlan()
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan, done: 1.0, readiness: false), today: raceDay.adding(days: 1)))
        #expect(review.readinessFirst == nil && review.readinessLast == nil && review.lowReadinessDays == 0)
    }

    @Test func fullyDoneCycleCountsEveryKeyWorkout() throws {
        let plan = makePlan()
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan, done: 1.0), today: raceDay.adding(days: 1)))
        let longs = plan.workouts.filter { $0.kind == .long }
        #expect(review.long == TrainerCycleCount(done: longs.count, total: longs.count))
        #expect(review.long.total > 0 && review.threshold.total > 0 && review.vo2.total > 0)
        #expect(review.threshold.done == review.threshold.total)
        #expect(review.vo2.done == review.vo2.total)
        #expect(review.longsMissed == 0)
        #expect(review.longestLongPlannedMeters == longs.map(\.totalMeters).max())
        #expect(abs(review.doneShare - 1) < 0.01)
        #expect(review.readinessFirst == 72 && review.readinessLast == 72)
        let tenK = try #require(review.predictions.first { $0.meters == 10_000 })
        #expect(tenK.first - tenK.last == Double(plan.weeks.count - 1))
        #expect(review.verdict == .increase)
        #expect(review.suggestedPeakMeters > review.currentPeakMeters)
    }

    @Test func skippedCycleMissesEveryLong() throws {
        let plan = makePlan()
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan), today: raceDay.adding(days: 1)))
        #expect(review.long.done == 0)
        #expect(review.longsMissed == review.long.total)
        #expect(review.doneShare == 0)
        #expect(review.raceSeconds == nil)
    }

    @Test func droppingReadinessShowsInTheLastWeeks() throws {
        let plan = makePlan()
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan, done: 1.0, readinessDrop: 20), today: raceDay.adding(days: 1)))
        let first = try #require(review.readinessFirst)
        let last = try #require(review.readinessLast)
        #expect(first > last)
        #expect(review.lowReadinessDays > 0)
    }

    @Test func lightWeeksInsideTheCycleAreListed() throws {
        var plan = makePlan()
        let light = monday.adding(days: 7 * 3)
        plan.lightWeeks = [light, monday.adding(days: 7 * 40)]
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: history(plan, done: 1.0), today: raceDay.adding(days: 1)))
        #expect(review.extraLightWeeks == [light])
    }

    @Test func raceDayWithoutAnyRunHasNoReview() {
        let plan = makePlan()
        #expect(TrainerEngine.cycleReview(plan: plan, history: history(plan), today: raceDay) == nil)
    }

    @Test func closingOnRaceDayLeavesLaterWorkoutsOut() throws {
        let plan = makePlan()
        let done = history(plan, done: 1.0, raceSeconds: 5_628)
        var withSunday = plan
        withSunday.workouts.append(TrainerWorkout(day: raceDay.adding(days: 1), kind: .long, title: "Longão", totalMeters: 16_000, steps: [], rationale: ""))
        let review = try #require(TrainerEngine.cycleReview(plan: withSunday, history: done, today: raceDay))
        let longs = plan.workouts.filter { $0.kind == .long && $0.day <= raceDay }
        #expect(review.long == TrainerCycleCount(done: longs.count, total: longs.count))
        #expect(review.longsMissed == 0)
    }

    @Test func roundGoalDistanceUsesTheNearestPredictionKey() throws {
        var plan = makePlan()
        plan.target.distanceMeters = 21_000
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: halfPredictions(plan), today: raceDay.adding(days: 1)))
        let half = try #require(review.predictions.first { $0.meters == 21_097.5 })
        #expect(half.first == 5_900 && half.last == 5_900 - Double(plan.weeks.count - 1) * 3)
        #expect(review.predictions.map(\.meters) == [10_000, 21_097.5])
    }

    @Test func exactGoalDistanceUsesItsPredictionKey() throws {
        let plan = makePlan()
        let review = try #require(TrainerEngine.cycleReview(plan: plan, history: halfPredictions(plan), today: raceDay.adding(days: 1)))
        let half = try #require(review.predictions.first { $0.meters == 21_097.5 })
        #expect(half.first == 5_900 && half.last == 5_900 - Double(plan.weeks.count - 1) * 3)
        #expect(review.predictions.count == 2)
    }

    private func halfPredictions(_ plan: TrainerPlan) -> TrainerHistory {
        var result = history(plan, done: 1.0)
        for (offset, week) in plan.weeks.enumerated() {
            result.predictionSeries[week.start]?[21_097.5] = 5_900 - Double(offset) * 3
        }
        return result
    }

    private func makeOpenPlan(weeks: Int) -> TrainerPlan {
        let target = TrainerTarget(kind: .text, name: "Correr melhor", text: "Correr melhor")
        var plan = TrainerEngine.create(
            target: target, structure: TrainerEngine.defaultStructure, strength: [], history: makeHistory(),
            today: monday, now: now, startMeters: 60_000, peakMeters: 80_000
        )
        var index = 1
        while plan.weeks.count < weeks, let week = plan.weeks.first(where: { $0.index == index }) {
            plan = TrainerEngine.adjust(plan, history: makeHistory(), today: week.start.adding(days: 7), now: now, trigger: .weekEnded(index))
            index += 1
        }
        return plan
    }
}
