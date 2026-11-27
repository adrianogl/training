import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerRulesRefreshTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var tuesday: Day { monday.adding(days: 1) }
    private var thursday: Day { monday.adding(days: 3) }
    private var saturday: Day { monday.adding(days: 5) }

    private var target: TrainerTarget {
        TrainerTarget(kind: .race, name: "Meia maratona", date: monday.adding(days: 12 * 7 + 5), distanceMeters: 21_097.5, goalSeconds: 5_700)
    }

    private func run(_ id: Int64, _ day: Day, km: Double, pace: Double, kind: RunKind) -> TrainerRun {
        TrainerRun(activityId: id, day: day, meters: km * 1_000, seconds: km * pace, kind: kind)
    }

    private var history: TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(run(base + 1, start, km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 2, start.adding(days: 1), km: 10, pace: 262, kind: .tempo))
            runs.append(run(base + 3, start.adding(days: 2), km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 4, start.adding(days: 5), km: Double(18 - week), pace: 335, kind: .long))
        }
        return TrainerHistory(runs: runs, predictions: [10_000: 2_580, 5_000: 1_230])
    }

    private var historyWithTuesday: TrainerHistory {
        var value = history
        value.runs.append(run(99, tuesday, km: 10, pace: 262, kind: .tempo))
        return value
    }

    private func createPlan() -> TrainerPlan {
        TrainerEngine.create(
            target: target, structure: TrainerEngine.defaultStructure, strength: [], history: history, today: monday, now: now
        )
    }

    private func shifted(_ workout: TrainerWorkout) -> TrainerWorkout {
        var copy = workout
        copy.paceLow = copy.paceLow.map { $0 - 20 }
        copy.paceHigh = copy.paceHigh.map { $0 - 20 }
        copy.steps = copy.steps.map { step in
            var moved = step
            moved.paceLow = moved.paceLow.map { $0 - 20 }
            moved.paceHigh = moved.paceHigh.map { $0 - 20 }
            return moved
        }
        return copy
    }

    private func stalePlan() -> TrainerPlan {
        var plan = createPlan()
        plan.rulesVersion = nil
        plan.workouts = plan.workouts.map { workout in
            var copy = shifted(workout)
            if workout.day == thursday { copy.edited = true }
            return copy
        }
        return plan
    }

    private func workout(_ plan: TrainerPlan, on day: Day) throws -> TrainerWorkout {
        try #require(plan.workouts.first { $0.day == day })
    }

    @Test func newPlanCarriesCurrentRulesVersion() {
        #expect(createPlan().rulesVersion == TrainerEngineConstants.prescriptionRulesVersion)
    }

    @Test func currentPlanIsNotRefreshed() {
        #expect(TrainerEngine.refreshingRules(createPlan(), history: history, today: thursday, now: now) == nil)
    }

    @Test func endedPlanIsNotRefreshed() {
        var plan = stalePlan()
        plan.endedOn = monday
        #expect(TrainerEngine.refreshingRules(plan, history: history, today: thursday, now: now) == nil)
    }

    @Test func stalePlanIsRebuiltFromToday() throws {
        let stale = stalePlan()
        let refreshed = try #require(TrainerEngine.refreshingRules(stale, history: historyWithTuesday, today: tuesday, now: now))

        #expect(refreshed.rulesVersion == TrainerEngineConstants.prescriptionRulesVersion)
        let long = try workout(refreshed, on: saturday)
        #expect(long != (try workout(stale, on: saturday)))
        #expect(long.kind == .long)
        #expect(long.paceLow != (try workout(stale, on: saturday)).paceLow)

        let version = try #require(refreshed.versions.last)
        #expect(version.number == (stale.versions.last?.number ?? 0) + 1)
        #expect(version.summary == "Treinos refeitos com as regras novas de zonas e ritmos.")
        #expect(TrainerEngine.isRulesRefresh(version.trigger))
        #expect(!version.changes.isEmpty)
        #expect(version.changes.allSatisfy { change in change.day.map { $0 >= tuesday } ?? true })

        #expect(TrainerEngine.refreshingRules(refreshed, history: historyWithTuesday, today: tuesday, now: now) == nil)
    }

    @Test func refreshKeepsPastDoneAndEditedWorkouts() throws {
        let stale = stalePlan()
        let refreshed = try #require(TrainerEngine.refreshingRules(stale, history: historyWithTuesday, today: tuesday, now: now))

        #expect(try workout(refreshed, on: monday) == (try workout(stale, on: monday)))
        #expect(try workout(refreshed, on: tuesday) == (try workout(stale, on: tuesday)))
        #expect(try workout(refreshed, on: thursday) == (try workout(stale, on: thursday)))
        #expect(refreshed.weeks.first?.start == stale.weeks.first?.start)
    }

    @Test func refreshKeepsPlanSettings() throws {
        var stale = stalePlan()
        stale.paceOverrides = [.easy: 350]
        stale.outAndBack = true
        stale.lightWeeks = [monday.adding(days: 21)]
        let refreshed = try #require(TrainerEngine.refreshingRules(stale, history: history, today: tuesday, now: now))

        #expect(refreshed.target == stale.target)
        #expect(refreshed.structure == stale.structure)
        #expect(refreshed.strength == stale.strength)
        #expect(refreshed.longMode == stale.longMode)
        #expect(refreshed.outAndBack)
        #expect(refreshed.paceOverrides == [.easy: 350])
        #expect(refreshed.lightWeeks == stale.lightWeeks)
        #expect(refreshed.dayPreference == stale.dayPreference)
        #expect(refreshed.processedActivityIds == stale.processedActivityIds)
    }

    @Test func savedPlanWithoutRulesVersionDecodesAsStale() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(createPlan())
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["rulesVersion"] as? Int == TrainerEngineConstants.prescriptionRulesVersion)
        object.removeValue(forKey: "rulesVersion")

        let decoded = try decoder.decode(TrainerPlan.self, from: try JSONSerialization.data(withJSONObject: object))

        #expect(decoded.rulesVersion == nil)
        #expect(TrainerEngine.refreshingRules(decoded, history: history, today: tuesday, now: now) != nil)
    }

    private var seventhMonday: Day { monday.adding(days: 6 * 7) }

    private func staled(_ plan: TrainerPlan) -> TrainerPlan {
        var copy = plan
        copy.rulesVersion = nil
        copy.workouts = copy.workouts.map(shifted)
        return copy
    }

    @Test func refreshLaterInTheCycleKeepsSkeletonAndDistances() throws {
        let stale = staled(createPlan())
        let today = seventhMonday.adding(days: 2)
        let refreshed = try #require(TrainerEngine.refreshingRules(stale, history: history, today: today, now: now))

        #expect(refreshed.weeks.map(\.targetMeters) == stale.weeks.map(\.targetMeters))
        #expect(refreshed.weeks.map(\.longMeters) == stale.weeks.map(\.longMeters))
        #expect(refreshed.weeks.map(\.thresholdFocus) == stale.weeks.map(\.thresholdFocus))
        #expect(refreshed.weeks.map(\.vo2Focus) == stale.weeks.map(\.vo2Focus))
        #expect(refreshed.weeks.map(\.phase) == stale.weeks.map(\.phase))
        #expect(refreshed.longStage == stale.longStage)
        let future = { (plan: TrainerPlan) in plan.workouts.filter { $0.day >= today } }
        #expect(future(refreshed).map(\.day) == future(stale).map(\.day))
        #expect(future(refreshed).map(\.kind) == future(stale).map(\.kind))
        #expect(future(refreshed).map(\.totalMeters) == future(stale).map(\.totalMeters))
        #expect(future(refreshed).map(\.paceLow) != future(stale).map(\.paceLow))
        #expect(refreshed.workouts.filter { $0.day < today } == stale.workouts.filter { $0.day < today })
    }

    @Test func tomorrowsLongKeepsDistanceWithNewPace() throws {
        let stale = staled(createPlan())
        let friday = seventhMonday.adding(days: 4)
        let refreshed = try #require(TrainerEngine.refreshingRules(stale, history: history, today: friday, now: now))

        let before = try workout(stale, on: friday.adding(days: 1))
        let after = try workout(refreshed, on: friday.adding(days: 1))
        #expect(after.kind == .long)
        #expect(after.totalMeters == before.totalMeters)
        #expect(after.paceLow != before.paceLow)
        #expect(after.paceHigh != before.paceHigh)
    }

    @Test func activePainRequestStaysApplied() throws {
        let today = seventhMonday.adding(days: 1)
        let pain = TrainerRequest(category: .pain, text: "Dor na canela", from: today)
        let hurt = TrainerEngine.adjust(createPlan(), history: history, today: today, now: now, trigger: .request(pain))
        let stale = staled(hurt)
        let refreshed = try #require(TrainerEngine.refreshingRules(stale, history: history, today: today, now: now))

        let period = today...TrainerEngine.end(of: pain)
        let inPeriod = { (plan: TrainerPlan) in plan.workouts.filter { period.contains($0.day) } }
        #expect(!inPeriod(refreshed).isEmpty)
        #expect(inPeriod(refreshed).map(\.kind) == inPeriod(hurt).map(\.kind))
        #expect(inPeriod(refreshed).map(\.totalMeters) == inPeriod(hurt).map(\.totalMeters))
        #expect(!inPeriod(refreshed).contains { $0.kind == .threshold || $0.kind == .vo2max })
    }
}
