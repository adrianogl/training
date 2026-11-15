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
        #expect(review.verdict == .keep && review.reasons.isEmpty)
        #expect(review.suggestedStartMeters == review.currentStartMeters && review.suggestedPeakMeters == review.currentPeakMeters)
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

    private func history(
        _ plan: TrainerPlan, done: Double = 0, readiness: Bool = true, readinessDrop: Int = 0, raceSeconds: Double? = nil
    ) -> TrainerHistory {
        var runs: [TrainerRun] = []
        if done > 0 {
            for (offset, workout) in plan.workouts.sorted(by: { $0.day < $1.day }).enumerated() where workout.totalMeters > 0 {
                let meters = workout.totalMeters * done
                let pace = workout.paceLow ?? plan.paces.easy
                let seconds = workout.kind == .race ? raceSeconds ?? meters / 1_000 * pace : meters / 1_000 * pace
                runs.append(TrainerRun(activityId: Int64(1_000 + offset), day: workout.day, meters: meters, seconds: seconds, kind: runKind(workout.kind)))
            }
        }
        if let raceSeconds, !runs.contains(where: { $0.day == raceDay && $0.kind == .race }) {
            runs.append(TrainerRun(activityId: 999, day: raceDay, meters: 21_097.5, seconds: raceSeconds, kind: .race))
        }
        let first = plan.weeks.first?.start ?? monday
        let span = max(1, first.days(until: plan.weeks.last?.start.adding(days: 6) ?? first))
        var values: [Day: Int] = [:]
        if readiness {
            for offset in 0...span {
                values[first.adding(days: offset)] = 72 - Int((Double(readinessDrop * offset) / Double(span)).rounded())
            }
        }
        var predictionSeries: [Day: [Double: Double]] = [:]
        for (offset, week) in plan.weeks.enumerated() {
            predictionSeries[week.start] = [10_000: 2_460 - Double(offset)]
        }
        return TrainerHistory(runs: runs, readiness: values, predictions: [10_000: 2_460], predictionSeries: predictionSeries)
    }

    private func runKind(_ kind: TrainerDayKind) -> RunKind {
        switch kind {
        case .long: .long
        case .threshold: .tempo
        case .vo2max: .intervals
        case .race: .race
        default: .easy
        }
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
