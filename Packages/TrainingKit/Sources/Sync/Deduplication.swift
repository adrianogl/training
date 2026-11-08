import Foundation
import Storage
import SwiftData

extension SyncEngine {
    func removeDuplicates() throws -> Int {
        var daily = FetchDescriptor<DailyRecord>()
        daily.propertiesToFetch = [\.day, \.updatedAt]
        var activities = FetchDescriptor<ActivityRecord>()
        activities.propertiesToFetch = [\.activityId, \.updatedAt]
        let removed = deleteDuplicates(try modelContext.fetch(daily), key: \.day, updatedAt: \.updatedAt)
            + deleteDuplicates(try modelContext.fetch(activities), key: \.activityId, updatedAt: \.updatedAt)
        if removed > 0 {
            try modelContext.save()
        }
        return removed
    }

    private func deleteDuplicates<Model: PersistentModel, Key: Hashable>(
        _ models: [Model],
        key: KeyPath<Model, Key>,
        updatedAt: KeyPath<Model, Date>
    ) -> Int {
        var removed = 0
        for group in Dictionary(grouping: models, by: { $0[keyPath: key] }).values where group.count > 1 {
            let sorted = group.sorted { $0[keyPath: updatedAt] > $1[keyPath: updatedAt] }
            for duplicate in sorted.dropFirst() {
                modelContext.delete(duplicate)
                removed += 1
            }
        }
        return removed
    }
}
