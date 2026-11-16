import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct TrainerSignalsTests {
    private let plan = makePlan()

    private var week: TrainerWeek { plan.weeks[2] }
    private var start: Day { week.start }
    private var end: Day { week.start.adding(days: 6) }

    private func signals(_ history: TrainerHistory) -> [TrainerSignal] {
        TrainerEngine.signals(plan: plan, history: history, week: week)
    }

    private func baseline<T>(_ value: (Int) -> T, days: Int = 60) -> [Day: T] {
        var result: [Day: T] = [:]
        for offset in 1...days { result[start.adding(days: -offset)] = value(offset) }
        return result
    }

    private func weekValues<T>(_ value: T, days: Int = 7) -> [Day: T] {
        var result: [Day: T] = [:]
        for offset in 0..<days { result[start.adding(days: offset)] = value }
        return result
    }

    private func hrvHistory(week value: Double, weekDays: Int = 7, baselineDays: Int = 60) -> TrainerHistory {
        let base = baseline({ $0 % 2 == 0 ? 50.0 : 70.0 }, days: baselineDays)
        return TrainerHistory(runs: [], hrv: base.merging(weekValues(value, days: weekDays)) { $1 })
    }

    @Test func emptyHistoryHasNoSignals() {
        #expect(signals(TrainerHistory(runs: [])).isEmpty)
    }

    @Test func bodySignalsAreHrvRestingAndSleep() {
        #expect(TrainerSignal.allCases.filter(\.isBody) == [.hrv, .restingHeartRate, .sleep])
    }

    @Test func hrvBelowHalfDeviationFires() {
        #expect(signals(hrvHistory(week: 54.9)) == [.hrv])
    }

    @Test func hrvAtHalfDeviationDoesNotFire() {
        #expect(signals(hrvHistory(week: 55)).isEmpty)
    }

    @Test func hrvWithThreeWeekDaysDoesNotFire() {
        #expect(signals(hrvHistory(week: 30, weekDays: 3)).isEmpty)
    }

    @Test func hrvWithThirteenBaselineDaysDoesNotFire() {
        #expect(signals(hrvHistory(week: 30, baselineDays: 13)).isEmpty)
    }

    @Test func hrvWithFourteenBaselineDaysFires() {
        #expect(signals(hrvHistory(week: 30, baselineDays: 14)) == [.hrv])
    }

    @Test func baselineExcludesTheWeek() {
        let base = baseline({ _ in 60.0 }, days: 13)
        let history = TrainerHistory(runs: [], hrv: base.merging(weekValues(40.0)) { $1 })
        #expect(signals(history).isEmpty)
    }

    @Test func baselineStopsAtSixtyDays() {
        var values = baseline({ _ in 60.0 }, days: 13)
        values[start.adding(days: -61)] = 60
        values[start.adding(days: -70)] = 60
        let history = TrainerHistory(runs: [], hrv: values.merging(weekValues(40.0)) { $1 })
        #expect(signals(history).isEmpty)
    }

    @Test func restingThreeAboveFires() {
        let values = baseline({ _ in 50 }).merging(weekValues(53)) { $1 }
        #expect(signals(TrainerHistory(runs: [], restingHeartRate: values)) == [.restingHeartRate])
    }

    @Test func restingTwoAboveDoesNotFire() {
        let values = baseline({ _ in 50 }).merging(weekValues(52)) { $1 }
        #expect(signals(TrainerHistory(runs: [], restingHeartRate: values)).isEmpty)
    }

    @Test func restingWithThreeWeekDaysDoesNotFire() {
        let values = baseline({ _ in 50 }).merging(weekValues(70, days: 3)) { $1 }
        #expect(signals(TrainerHistory(runs: [], restingHeartRate: values)).isEmpty)
    }

    @Test func sleepFortyFiveMinutesBelowFires() {
        let values = baseline({ _ in 28_800 }).merging(weekValues(26_100)) { $1 }
        #expect(signals(TrainerHistory(runs: [], sleepSeconds: values)) == [.sleep])
    }

    @Test func sleepJustUnderFortyFiveMinutesBelowDoesNotFire() {
        let values = baseline({ _ in 28_800 }).merging(weekValues(26_101)) { $1 }
        #expect(signals(TrainerHistory(runs: [], sleepSeconds: values)).isEmpty)
    }

    @Test func sleepWithThirteenBaselineDaysDoesNotFire() {
        let values = baseline({ _ in 28_800 }, days: 13).merging(weekValues(20_000)) { $1 }
        #expect(signals(TrainerHistory(runs: [], sleepSeconds: values)).isEmpty)
    }

    private func loadHistory(week value: Double) -> TrainerHistory {
        var load: [Day: Double] = [:]
        for offset in 7..<28 { load[end.adding(days: -offset)] = 10 }
        for offset in 0..<7 { load[end.adding(days: -offset)] = value }
        return TrainerHistory(runs: [], dailyLoad: load)
    }

    @Test func loadAboveRatioFires() {
        #expect(signals(loadHistory(week: 15)) == [.load])
    }

    @Test func loadBelowRatioDoesNotFire() {
        #expect(signals(loadHistory(week: 14)).isEmpty)
    }

    @Test func loadOutsideTheWindowDoesNotFire() {
        let history = TrainerHistory(runs: [], dailyLoad: [end.adding(days: 1): 500, start.adding(days: -30): 10])
        #expect(signals(history).isEmpty)
    }

    @Test func loadWithSingleDayDoesNotFire() {
        #expect(signals(TrainerHistory(runs: [], dailyLoad: [end: 500])).isEmpty)
    }

    @Test func loadWithEmptyBaselineBeforeTheWeekDoesNotFire() {
        var load: [Day: Double] = [:]
        for offset in 0..<7 { load[start.adding(days: offset)] = 50 }
        #expect(signals(TrainerHistory(runs: [], dailyLoad: load)).isEmpty)
    }

    @Test func loadWithEightDaysIncludingOneBeforeTheWeekFires() {
        var load: [Day: Double] = [start.adding(days: -1): 10]
        for offset in 0..<7 { load[start.adding(days: offset)] = 50 }
        #expect(signals(TrainerHistory(runs: [], dailyLoad: load)) == [.load])
    }

    @Test func readinessBelowFiftyFiveFires() {
        #expect(signals(TrainerHistory(runs: [], readiness: weekValues(54, days: 4))) == [.readiness])
    }

    @Test func readinessAtFiftyFiveDoesNotFire() {
        #expect(signals(TrainerHistory(runs: [], readiness: weekValues(55))).isEmpty)
    }

    @Test func readinessWithThreeDaysDoesNotFire() {
        #expect(signals(TrainerHistory(runs: [], readiness: weekValues(20, days: 3))).isEmpty)
    }

    private var qualities: [TrainerWorkout] {
        plan.workouts
            .filter { ($0.kind == .threshold || $0.kind == .vo2max) && $0.day <= end }
            .sorted { $0.day < $1.day }
    }

    private func qualityRun(_ workout: TrainerWorkout, id: Int64, offTarget: Bool) -> TrainerRun {
        TrainerRun(
            activityId: id, day: workout.day, meters: workout.totalMeters, seconds: workout.totalMeters / 1_000 * 300,
            kind: workout.kind == .threshold ? .tempo : .intervals, activeOnTarget: offTarget ? 3 : 5, activeTotal: 5
        )
    }

    @Test func twoQualitiesOffTargetFire() throws {
        let list = qualities
        try #require(list.count >= 3)
        let runs = [
            qualityRun(list[list.count - 3], id: 1, offTarget: false),
            qualityRun(list[list.count - 2], id: 2, offTarget: true),
            qualityRun(list[list.count - 1], id: 3, offTarget: true),
        ]
        #expect(signals(TrainerHistory(runs: runs)) == [.performance])
    }

    @Test func oneQualityOffTargetDoesNotFire() throws {
        let list = qualities
        try #require(list.count >= 3)
        let runs = [
            qualityRun(list[list.count - 3], id: 1, offTarget: true),
            qualityRun(list[list.count - 2], id: 2, offTarget: false),
            qualityRun(list[list.count - 1], id: 3, offTarget: true),
        ]
        #expect(signals(TrainerHistory(runs: runs)).isEmpty)
    }

    @Test func missedQualityIsSkippedWhenCountingOffTarget() throws {
        let list = qualities
        try #require(list.count >= 3)
        let runs = [
            qualityRun(list[list.count - 3], id: 1, offTarget: true),
            qualityRun(list[list.count - 2], id: 2, offTarget: true),
        ]
        #expect(signals(TrainerHistory(runs: runs)) == [.performance])
    }

    @Test func singleQualityWithStatusDoesNotFire() throws {
        let list = qualities
        try #require(!list.isEmpty)
        let runs = [qualityRun(list[list.count - 1], id: 1, offTarget: true)]
        #expect(signals(TrainerHistory(runs: runs)).isEmpty)
    }

    @Test func qualityAfterTheWeekIsIgnored() throws {
        let later = plan.workouts
            .filter { ($0.kind == .threshold || $0.kind == .vo2max) && $0.day > end }
            .sorted { $0.day < $1.day }
        try #require(later.count >= 2)
        let runs = [qualityRun(later[0], id: 1, offTarget: true), qualityRun(later[1], id: 2, offTarget: true)]
        #expect(signals(TrainerHistory(runs: runs)).isEmpty)
    }

    private func easy(_ id: Int64, _ day: Day, pace: Double, heartRate: Double?) -> TrainerRun {
        TrainerRun(activityId: id, day: day, meters: 10_000, seconds: pace * 10, kind: .easy, averageHeartRate: heartRate)
    }

    private func easyHistory(baselineHeartRate: Double, matching: Int = 3, weekRuns: Int = 2, extra: [TrainerRun] = []) -> TrainerHistory {
        var runs: [TrainerRun] = []
        for index in 0..<weekRuns {
            runs.append(easy(Int64(100 + index), start.adding(days: index * 2), pace: index == 0 ? 355 : 365, heartRate: 150))
        }
        for index in 0..<matching {
            runs.append(easy(Int64(200 + index), start.adding(days: -3 - index * 5), pace: 368, heartRate: baselineHeartRate))
        }
        return TrainerHistory(runs: runs + extra)
    }

    @Test func easyHeartRateFiveAboveFires() {
        #expect(signals(easyHistory(baselineHeartRate: 145)) == [.performance])
    }

    @Test func easyHeartRateFourAboveDoesNotFire() {
        let outside = [
            easy(300, start.adding(days: -10), pace: 371, heartRate: 100),
            easy(301, start.adding(days: -20), pace: 349, heartRate: 100),
            easy(302, start.adding(days: -61), pace: 360, heartRate: 100),
            easy(303, start.adding(days: -12), pace: 360, heartRate: nil),
            TrainerRun(activityId: 304, day: start.adding(days: -14), meters: 10_000, seconds: 3_600, kind: .long, averageHeartRate: 100),
        ]
        #expect(signals(easyHistory(baselineHeartRate: 146, extra: outside)).isEmpty)
    }

    @Test func easyWithTwoMatchingBaselineRunsDoesNotFire() {
        #expect(signals(easyHistory(baselineHeartRate: 120, matching: 2)).isEmpty)
    }

    @Test func easyWithOneWeekRunDoesNotFire() {
        #expect(signals(easyHistory(baselineHeartRate: 120, weekRuns: 1)).isEmpty)
    }

    @Test func signalsFollowCaseOrder() {
        var history = hrvHistory(week: 30)
        history.readiness = weekValues(40)
        history.restingHeartRate = baseline({ _ in 50 }).merging(weekValues(60)) { $1 }
        #expect(signals(history) == [.hrv, .restingHeartRate, .readiness])
    }
}
