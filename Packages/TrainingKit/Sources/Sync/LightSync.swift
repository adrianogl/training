import Foundation
import GarminAPI
import Storage
import SwiftData
import TrainingCore

extension SyncEngine {
    func performLight() async throws -> SyncReport {
        var report = SyncReport()
        let page: [ActivityDTO]
        do {
            page = try await source.activities(start: 0, limit: SyncConstants.lightActivityPageSize, from: nil, to: nil)
        } catch GarminAPIError.rateLimited(_) {
            report.stoppedByRateLimit = true
            return report
        }
        for dto in page {
            try upsertActivity(dto)
        }
        try modelContext.save()
        report.activitiesUpserted = page.count

        let fit = try await processFITQueue(try lightFITQueue(ids: Set(page.map(\.activityId)))) { _ in }
        report.fitProcessed = fit.processed
        report.processedActivityIds = fit.activityIds
        report.fitStoppedByRateLimit = fit.stoppedByRateLimit
        report.stoppedByRateLimit = fit.stoppedByRateLimit
        report.skippedFITs = fit.skipped
        return report
    }

    private func lightFITQueue(ids: Set<Int64>) throws -> [ActivityRecord] {
        let maxFailures = SyncConstants.maxFitTransientFailures
        let pending = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { !$0.fitProcessed && $0.fitTransientFailures < maxFailures },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        return try modelContext.fetch(pending).filter { ids.contains($0.activityId) && ActivityTypeKey.isRun($0.typeKey) }
    }
}
