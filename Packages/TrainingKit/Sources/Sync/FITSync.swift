import FITReader
import Foundation
import Storage
import SwiftData

extension SyncEngine {
    func processPendingFIT(progress: (Double) -> Void) async throws -> Int {
        let descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { !$0.fitProcessed },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        let pending = try modelContext.fetch(descriptor).filter { ActivityKind.isRun($0.typeKey) }
        var processed = 0
        for (index, record) in pending.enumerated() {
            if let result = await readFIT(activityId: record.activityId) {
                record.vo2max = result.summary.physio?.vo2max
                record.recoveryMinutes = result.summary.physio?.recoveryMinutes
                record.performanceCondition = result.summary.physio?.performanceCondition
                record.samplesData = result.samples
                record.routeData = result.route
                record.fitProcessed = true
                record.updatedAt = .now
                try modelContext.save()
                processed += 1
            }
            progress(Double(index + 1) / Double(pending.count))
        }
        return processed
    }

    private func readFIT(activityId: Int64) async -> (summary: FITSummary, samples: Data, route: Data)? {
        do {
            let summary = try FITReader.read(zip: try await source.fitArchive(activityId: activityId))
            let encoder = JSONEncoder()
            return (summary, try encoder.encode(summary.samples), try encoder.encode(summary.route))
        } catch {
            return nil
        }
    }
}
