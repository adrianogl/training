import Foundation
import Storage
import SwiftData

extension AppModel {
    func isOwnActivity(_ id: Int64) -> Bool {
        ActivityExclusionStore(url: scope.activityExclusionsURL).isOwn(id)
    }

    func deleteActivity(_ id: Int64) async -> String? {
        let store = ActivityExclusionStore(url: scope.activityExclusionsURL)
        if store.isOwn(id) {
            guard let client = garminAccount.client else { return ActivityExclusionConstants.noGarmin }
            do {
                _ = try await client.delete(String(format: ActivityExclusionConstants.activityPathFormat, id))
            } catch {
                return ActivityExclusionConstants.garminFailed
            }
        }
        store.markDeleted(id)
        let context = container.mainContext
        var descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == id })
        descriptor.fetchLimit = 1
        if let record = try? context.fetch(descriptor).first {
            context.delete(record)
            try? context.save()
        }
        remoteSync.scheduleSync()
        Task { await syncNow(.pull) }
        return nil
    }
}
