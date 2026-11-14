import Foundation
import Testing
@testable import trAIning

@Suite struct WorkoutNoticeSelectionTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let window = WorkoutNoticeConstants.recentWindow

    private func workout(endedMinutesAgo minutes: Double, id: UUID = UUID()) -> FinishedWorkout {
        let end = now.addingTimeInterval(-minutes * 60)
        return FinishedWorkout(id: id, start: end.addingTimeInterval(-30 * 60), end: end)
    }

    private func due(_ workouts: [FinishedWorkout], enabledMinutesAgo: Double = 600, notified: Set<UUID> = []) -> [FinishedWorkout] {
        WorkoutNoticeSelection.due(workouts: workouts, enabledAt: now.addingTimeInterval(-enabledMinutesAgo * 60), now: now, notified: notified, window: window)
    }

    @Test func includesRunFinishedAfterEnabledWithinWindow() {
        let run = workout(endedMinutesAgo: 5)
        #expect(due([run]) == [run])
    }

    @Test func ignoresRunFinishedBeforeEnabled() {
        #expect(due([workout(endedMinutesAgo: 90)], enabledMinutesAgo: 60).isEmpty)
    }

    @Test func ignoresRunOlderThanWindow() {
        #expect(due([workout(endedMinutesAgo: window / 60 + 10)]).isEmpty)
    }

    @Test func ignoresAlreadyNotifiedWorkout() {
        let seen = workout(endedMinutesAgo: 20)
        let fresh = workout(endedMinutesAgo: 5)
        #expect(due([seen, fresh], notified: [seen.id]) == [fresh])
    }

    @Test func ordersByEndDate() {
        let first = workout(endedMinutesAgo: 60)
        let second = workout(endedMinutesAgo: 10)
        #expect(due([second, first]) == [first, second])
    }
}

@Suite struct PendingWorkoutQueueTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func pending(endedMinutesAgo minutes: Double, id: UUID = UUID()) -> PendingWorkout {
        let end = now.addingTimeInterval(-minutes * 60)
        return PendingWorkout(id: id, start: end.addingTimeInterval(-1_800), end: end)
    }

    @Test func addIgnoresDuplicateId() {
        let item = pending(endedMinutesAgo: 5)
        var queue = PendingWorkoutQueue()
        queue.add(item)
        queue.add(item)
        #expect(queue.items == [item])
    }

    @Test func removeDropsOnlyThatWorkout() {
        let kept = pending(endedMinutesAgo: 5)
        let dropped = pending(endedMinutesAgo: 10)
        var queue = PendingWorkoutQueue(items: [kept, dropped])
        queue.remove(id: dropped.id)
        #expect(queue.items == [kept])
    }

    @Test func pruneDropsExpiredWorkouts() {
        let recent = pending(endedMinutesAgo: 30)
        let old = pending(endedMinutesAgo: 600)
        var queue = PendingWorkoutQueue(items: [recent, old])
        queue.prune(now: now, lifetime: WorkoutNoticeConstants.recentWindow)
        #expect(queue.items == [recent])
    }

    @Test func saveAndLoadRoundTrip() throws {
        let defaults = try #require(UserDefaults(suiteName: "PendingWorkoutQueueTests.\(UUID().uuidString)"))
        let queue = PendingWorkoutQueue(items: [pending(endedMinutesAgo: 5), pending(endedMinutesAgo: 15)])
        queue.save(defaults: defaults)
        #expect(PendingWorkoutQueue.load(defaults: defaults) == queue)
        #expect(PendingWorkoutQueue.load(defaults: UserDefaults(suiteName: "PendingWorkoutQueueTests.\(UUID().uuidString)")!).items.isEmpty)
    }
}
