import Foundation
import Storage
import SwiftData
import Testing
@testable import trAIning

@Suite struct WorkoutNoticeSelectionTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let window = WorkoutNoticeConstants.recentWindow

    private func run(endedMinutesAgo minutes: Double, id: Int64 = 1, typeKey: String = "running") -> FinishedRun {
        let end = now.addingTimeInterval(-minutes * 60)
        return FinishedRun(activityId: id, typeKey: typeKey, start: end.addingTimeInterval(-1_800), end: end)
    }

    private func due(_ runs: [FinishedRun], enabledMinutesAgo: Double = 600, notified: Set<Int64> = []) -> [FinishedRun] {
        WorkoutNoticeSelection.due(records: runs, enabledAt: now.addingTimeInterval(-enabledMinutesAgo * 60), now: now, notified: notified, window: window)
    }

    @Test func includesRunEndedTwentyMinutesAgo() {
        let recent = run(endedMinutesAgo: 20)
        #expect(due([recent]) == [recent])
    }

    @Test func ignoresAlreadyNotifiedRun() {
        let seen = run(endedMinutesAgo: 20, id: 1)
        let fresh = run(endedMinutesAgo: 5, id: 2)
        #expect(due([seen, fresh], notified: [1]) == [fresh])
    }

    @Test func ignoresRunEndedSevenHoursAgo() {
        #expect(due([run(endedMinutesAgo: 7 * 60)]).isEmpty)
    }

    @Test func ignoresRunEndedBeforeEnabled() {
        #expect(due([run(endedMinutesAgo: 90)], enabledMinutesAgo: 60).isEmpty)
    }

    @Test func ignoresNonRun() {
        #expect(due([run(endedMinutesAgo: 20, typeKey: "strength_training")]).isEmpty)
    }

    @Test func ordersByEndDate() {
        let first = run(endedMinutesAgo: 60, id: 1)
        let second = run(endedMinutesAgo: 10, id: 2)
        #expect(due([second, first]) == [first, second])
    }

    @Test func finishedRunsEndAtStartPlusDurationOrMovingDuration() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        let start = now.addingTimeInterval(-3_600)
        context.insert(ActivityRecord(activityId: 7, typeKey: "running", name: "Corrida", start: start, duration: 1_800))
        context.insert(ActivityRecord(activityId: 8, typeKey: "running", name: "Só movimento", start: start, movingDuration: 1_500))
        context.insert(ActivityRecord(activityId: 9, typeKey: "running", name: "Sem duração", start: start))
        context.insert(ActivityRecord(activityId: 10, typeKey: "running", name: "Antiga", start: now.addingTimeInterval(-86_400), duration: 1_800))
        try context.save()

        let runs = WorkoutNoticeSelection.finishedRuns(since: now.addingTimeInterval(-WorkoutNoticeConstants.fetchWindow), in: ModelContext(container))

        #expect(Set(runs.map(\.activityId)) == [7, 8])
        #expect(runs.first { $0.activityId == 7 }?.end == start.addingTimeInterval(1_800))
        #expect(runs.first { $0.activityId == 8 }?.end == start.addingTimeInterval(1_500))
    }

    @Test func expectedRunMatchesGarminRunByStart() {
        let garmin = run(endedMinutesAgo: 10)
        let expected = ExpectedRun(start: garmin.start.addingTimeInterval(40), until: now.addingTimeInterval(1_800))
        let other = ExpectedRun(start: garmin.start.addingTimeInterval(-3_600), until: now.addingTimeInterval(1_800))
        #expect(WorkoutNoticeSelection.matches(expected, runs: [garmin], tolerance: WorkoutNoticeConstants.matchTolerance))
        #expect(!WorkoutNoticeSelection.matches(other, runs: [garmin], tolerance: WorkoutNoticeConstants.matchTolerance))
    }

    @Test func expectationLastsUntilItsDeadline() {
        let expected = ExpectedRun(start: now.addingTimeInterval(-3_600), until: now.addingTimeInterval(WorkoutNoticeConstants.expectedRunWindow))
        #expect(WorkoutNoticeSelection.expecting(expected, now: now))
        #expect(!WorkoutNoticeSelection.expecting(expected, now: now.addingTimeInterval(WorkoutNoticeConstants.expectedRunWindow)))
        #expect(!WorkoutNoticeSelection.expecting(nil, now: now))
    }
}

@Suite struct WorkoutNoticeThrottleTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let interval = WorkoutNoticeConstants.garminCheckInterval

    private func check(forced: Bool = false, pending: Bool, lastCheckMinutesAgo minutes: Double?) -> WorkoutNoticeCheck {
        WorkoutNoticeSelection.nextCheck(forced: forced, pending: pending, lastCheck: minutes.map { now.addingTimeInterval(-$0 * 60) }, now: now, interval: interval)
    }

    @Test func dataThreeMinutesAfterEmptyCheckSchedulesTheNextOne() {
        let lastCheck = now.addingTimeInterval(-3 * 60)
        #expect(check(pending: false, lastCheckMinutesAgo: 3) == .after(lastCheck.addingTimeInterval(interval)))
    }

    @Test func skipsWhenNothingPendingAndCheckedFourMinutesAgo() {
        #expect(check(pending: false, lastCheckMinutesAgo: 4) != .now)
    }

    @Test func checksWhenNothingPendingAndCheckedElevenMinutesAgo() {
        #expect(check(pending: false, lastCheckMinutesAgo: 11) == .now)
    }

    @Test func checksWhenNeverChecked() {
        #expect(check(pending: false, lastCheckMinutesAgo: nil) == .now)
    }

    private func healthWake(run: DateInterval?, matchedStart: Date? = nil, current: ExpectedRun? = nil) -> WorkoutNoticeCheck {
        let expectation = WorkoutNoticeSelection.newExpectation(healthRun: run, enabledAt: now.addingTimeInterval(-86_400), matchedStart: matchedStart, current: current, now: now, window: WorkoutNoticeConstants.expectedRunWindow)
        return check(forced: expectation != nil, pending: false, lastCheckMinutesAgo: 3)
    }

    @Test func healthWakeWithoutNewRunRespectsThrottle() {
        let run = DateInterval(start: now.addingTimeInterval(-3_600), end: now.addingTimeInterval(-1_800))
        let throttled = WorkoutNoticeCheck.after(now.addingTimeInterval(-3 * 60 + interval))
        #expect(healthWake(run: nil) == throttled)
        #expect(healthWake(run: run, matchedStart: run.start) == throttled)
        #expect(healthWake(run: run, current: ExpectedRun(start: run.start, until: now.addingTimeInterval(600))) == throttled)
    }

    @Test func healthWakeWithNewRunForcesCheck() {
        let run = DateInterval(start: now.addingTimeInterval(-3_600), end: now.addingTimeInterval(-1_800))
        #expect(healthWake(run: run) == .now)
    }

    @Test func healthRunBeforeEnabledCreatesNoExpectation() {
        let run = DateInterval(start: now.addingTimeInterval(-3_600), end: now.addingTimeInterval(-1_800))
        #expect(WorkoutNoticeSelection.newExpectation(healthRun: run, enabledAt: now.addingTimeInterval(-600), matchedStart: nil, current: nil, now: now, window: WorkoutNoticeConstants.expectedRunWindow) == nil)
        #expect(WorkoutNoticeSelection.newExpectation(healthRun: run, enabledAt: now.addingTimeInterval(-86_400), matchedStart: nil, current: nil, now: now, window: WorkoutNoticeConstants.expectedRunWindow) == ExpectedRun(start: run.start, until: now.addingTimeInterval(WorkoutNoticeConstants.expectedRunWindow)))
    }

    @Test func alwaysChecksWithPendingRun() {
        #expect(check(pending: true, lastCheckMinutesAgo: 1) == .now)
    }
}

@Suite struct PendingWorkoutQueueTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func pending(endedMinutesAgo minutes: Double, id: Int64) -> PendingWorkout {
        PendingWorkout(activityId: id, end: now.addingTimeInterval(-minutes * 60))
    }

    @Test func addIgnoresDuplicateActivity() {
        let item = pending(endedMinutesAgo: 5, id: 1)
        var queue = PendingWorkoutQueue()
        queue.add(item)
        queue.add(item)
        #expect(queue.items == [item])
    }

    @Test func removeDropsOnlyThatActivity() {
        let kept = pending(endedMinutesAgo: 5, id: 1)
        let dropped = pending(endedMinutesAgo: 10, id: 2)
        var queue = PendingWorkoutQueue(items: [kept, dropped])
        queue.remove(activityId: 2)
        #expect(queue.items == [kept])
    }

    @Test func pruneDropsExpiredWorkouts() {
        let recent = pending(endedMinutesAgo: 30, id: 1)
        let old = pending(endedMinutesAgo: 600, id: 2)
        var queue = PendingWorkoutQueue(items: [recent, old])
        queue.prune(now: now, lifetime: WorkoutNoticeConstants.recentWindow)
        #expect(queue.items == [recent])
    }

    @Test func saveAndLoadRoundTrip() throws {
        let defaults = try #require(UserDefaults(suiteName: "PendingWorkoutQueueTests.\(UUID().uuidString)"))
        let queue = PendingWorkoutQueue(items: [pending(endedMinutesAgo: 5, id: 1), pending(endedMinutesAgo: 15, id: 2)])
        queue.save(defaults: defaults)
        #expect(PendingWorkoutQueue.load(defaults: defaults) == queue)
    }

    @Test func loadDropsLegacyQueueKeyedByHealthUUID() throws {
        let defaults = try #require(UserDefaults(suiteName: "PendingWorkoutQueueTests.\(UUID().uuidString)"))
        let legacy = #"[{"id":"\#(UUID().uuidString)","start":0,"end":0}]"#
        defaults.set(Data(legacy.utf8), forKey: WorkoutNoticeConstants.pendingKey)
        #expect(PendingWorkoutQueue.load(defaults: defaults).items.isEmpty)
    }
}
