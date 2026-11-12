import FITReader
import Foundation
import Storage
import SwiftData
import TrainingCore

public func hasOutdatedRuns(in context: ModelContext) throws -> Bool {
    try !outdatedRuns(in: context, includesExhausted: false).isEmpty
}

func outdatedRuns(in context: ModelContext, includesExhausted: Bool) throws -> [ActivityRecord] {
    let currentVersion = FITReaderConstants.processingVersion
    let outdated = FetchDescriptor<ActivityRecord>(
        predicate: #Predicate { $0.fitProcessed && $0.processingVersion < currentVersion },
        sortBy: [SortDescriptor(\.start, order: .reverse)]
    )
    let maxFailures = SyncConstants.maxFitTransientFailures
    return try context.fetch(outdated).filter {
        ActivityTypeKey.isRun($0.typeKey) && (includesExhausted || $0.fitTransientFailures < maxFailures)
    }
}

extension SyncEngine {
    func fitQueue(includesNewRuns: Bool, limit: Int?) throws -> [ActivityRecord] {
        let maxFailures = SyncConstants.maxFitTransientFailures
        var queue = try pendingRuns().filter { includesNewRuns == ($0.fitTransientFailures < maxFailures) }
        queue += try outdatedRuns(in: modelContext, includesExhausted: !includesNewRuns)
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
