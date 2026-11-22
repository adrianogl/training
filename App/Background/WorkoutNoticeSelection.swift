import Foundation
import Storage
import SwiftData
import TrainingCore

enum WorkoutNoticeSelection {
    static func due(records: [FinishedRun], enabledAt: Date, now: Date, notified: Set<Int64>, window: TimeInterval) -> [FinishedRun] {
        records
            .filter { ActivityTypeKey.isRun($0.typeKey) && $0.end > enabledAt && $0.end >= now.addingTimeInterval(-window) && !notified.contains($0.activityId) }
            .sorted { $0.end < $1.end }
    }

    static func nextCheck(forced: Bool, pending: Bool, lastCheck: Date?, now: Date, interval: TimeInterval) -> WorkoutNoticeCheck {
        guard !forced, !pending, let lastCheck else { return .now }
        let next = lastCheck.addingTimeInterval(interval)
        return now >= next ? .now : .after(next)
    }

    static func newExpectation(healthRun: DateInterval?, enabledAt: Date, matchedStart: Date?, current: ExpectedRun?, now: Date, window: TimeInterval) -> ExpectedRun? {
        guard let healthRun, healthRun.end > enabledAt, healthRun.start != matchedStart, current?.start != healthRun.start else { return nil }
        return ExpectedRun(start: healthRun.start, until: now.addingTimeInterval(window))
    }

    static func expecting(_ expected: ExpectedRun?, now: Date) -> Bool {
        guard let expected else { return false }
        return now < expected.until
    }

    static func matches(_ expected: ExpectedRun, runs: [FinishedRun], tolerance: TimeInterval) -> Bool {
        runs.contains { ActivityTypeKey.isRun($0.typeKey) && abs($0.start.timeIntervalSince(expected.start)) <= tolerance }
    }

    static func finishedRuns(since: Date, in context: ModelContext) -> [FinishedRun] {
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= since }))) ?? []
        return records.compactMap { record in
            (record.duration ?? record.movingDuration).map { FinishedRun(activityId: record.activityId, typeKey: record.typeKey, start: record.start, end: record.start.addingTimeInterval($0)) }
        }
    }
}

extension PendingWorkoutQueue {
    mutating func add(_ workout: PendingWorkout) {
        guard !items.contains(where: { $0.activityId == workout.activityId }) else { return }
        items.append(workout)
    }

    mutating func remove(activityId: Int64) {
        items.removeAll { $0.activityId == activityId }
    }

    mutating func prune(now: Date, lifetime: TimeInterval) {
        items.removeAll { $0.end < now.addingTimeInterval(-lifetime) }
    }

    static func load(defaults: UserDefaults = AccountScope.current.defaults) -> PendingWorkoutQueue {
        let items = defaults.data(forKey: WorkoutNoticeConstants.pendingKey).flatMap { try? JSONDecoder().decode([PendingWorkout].self, from: $0) }
        return PendingWorkoutQueue(items: items ?? [])
    }

    func save(defaults: UserDefaults = AccountScope.current.defaults) {
        defaults.set(try? JSONEncoder().encode(items), forKey: WorkoutNoticeConstants.pendingKey)
    }
}
