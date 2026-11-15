import Foundation

enum WorkoutNoticeSelection {
    static func due(workouts: [FinishedWorkout], enabledAt: Date, now: Date, notified: Set<UUID>, window: TimeInterval) -> [FinishedWorkout] {
        workouts
            .filter { $0.end > enabledAt && $0.end >= now.addingTimeInterval(-window) && !notified.contains($0.id) }
            .sorted { $0.end < $1.end }
    }
}

extension PendingWorkoutQueue {
    mutating func add(_ workout: PendingWorkout) {
        guard !items.contains(where: { $0.id == workout.id }) else { return }
        items.append(workout)
    }

    mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
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
