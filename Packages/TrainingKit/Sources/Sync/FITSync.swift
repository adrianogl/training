import FITReader
import Foundation
import GarminAPI
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
            switch try await readFIT(activityId: record.activityId) {
            case .read(let summary, let samples, let route):
                record.vo2max = summary.physio?.vo2max
                record.recoveryMinutes = summary.physio?.recoveryMinutes
                record.performanceCondition = summary.physio?.performanceCondition
                record.samplesData = samples
                record.routeData = route
                record.fitProcessed = true
                record.updatedAt = .now
                try modelContext.save()
                processed += 1
            case .skipped:
                break
            case .rateLimited:
                return processed
            }
            progress(Double(index + 1) / Double(pending.count))
        }
        return processed
    }

    private func readFIT(activityId: Int64) async throws -> FITOutcome {
        do {
            let summary = try FITReader.read(zip: try await source.fitArchive(activityId: activityId))
            let encoder = JSONEncoder()
            return .read(summary: summary, samples: try encoder.encode(summary.samples), route: try encoder.encode(summary.route))
        } catch let error as GarminAPIError where SyncErrorPolicy.isCredentialFailure(error) {
            throw error
        } catch GarminAPIError.rateLimited(_) {
            return .rateLimited
        } catch {
            return .skipped
        }
    }
}
