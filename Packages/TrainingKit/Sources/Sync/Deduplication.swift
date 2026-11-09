import Foundation
import Storage
import SwiftData

extension SyncEngine {
    func removeDuplicates() throws -> Int {
        var daily = FetchDescriptor<DailyRecord>()
        daily.propertiesToFetch = [\.day, \.updatedAt]
        var activities = FetchDescriptor<ActivityRecord>()
        activities.propertiesToFetch = [\.activityId, \.updatedAt, \.fitProcessed, \.processingVersion]
        let removed = deleteDuplicates(try modelContext.fetch(daily), key: \.day) { $0.updatedAt > $1.updatedAt }
            + deleteDuplicates(try modelContext.fetch(activities), key: \.activityId) { a, b in
                if a.fitProcessed != b.fitProcessed { return a.fitProcessed }
                if a.processingVersion != b.processingVersion { return a.processingVersion > b.processingVersion }
                return a.updatedAt > b.updatedAt
            }
        if removed > 0 {
            try modelContext.save()
        }
        return removed
    }

    private func deleteDuplicates<Model: PersistentModel, Key: Hashable>(
        _ models: [Model],
        key: KeyPath<Model, Key>,
        keepsFirst: (Model, Model) -> Bool
    ) -> Int {
        var removed = 0
        for group in Dictionary(grouping: models, by: { $0[keyPath: key] }).values where group.count > 1 {
            let sorted = group.sorted(by: keepsFirst)
            for duplicate in sorted.dropFirst() {
                modelContext.delete(duplicate)
                removed += 1
            }
        }
        return removed
    }
}
