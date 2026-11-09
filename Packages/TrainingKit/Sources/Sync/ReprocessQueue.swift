import FITReader
import Foundation
import Storage
import SwiftData
import TrainingCore

extension SyncEngine {
    func fitQueue(includesNewRuns: Bool, limit: Int?) throws -> [ActivityRecord] {
        let currentVersion = FITReaderConstants.processingVersion
        let outdated = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.fitProcessed && $0.processingVersion < currentVersion },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        let maxFailures = SyncConstants.maxFitTransientFailures
        var queue = try pendingRuns().filter { includesNewRuns == ($0.fitTransientFailures < maxFailures) }
        queue += try modelContext.fetch(outdated).filter {
            ActivityTypeKey.isRun($0.typeKey) && (!includesNewRuns || $0.fitTransientFailures < maxFailures)
        }
        guard let limit else { return queue }
        return Array(queue.prefix(max(limit, 0)))
    }

    private func pendingRuns() throws -> [ActivityRecord] {
        let pending = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { !$0.fitProcessed },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        return try modelContext.fetch(pending).filter { ActivityTypeKey.isRun($0.typeKey) }
    }
}
