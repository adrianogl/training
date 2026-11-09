import FITReader
import Foundation
import GarminAPI
import Storage
import SwiftData
import TrainingCore

extension SyncEngine {
    func processFITQueue(_ queue: [ActivityRecord], progress: (Double) -> Void) async throws -> FITStepResult {
        var result = FITStepResult()
        for (index, record) in queue.enumerated() {
            try Task.checkCancellation()
            let wasProcessed = record.fitProcessed
            switch try await readFIT(activityId: record.activityId) {
            case .read(let summary, let samples, let route, let structure):
                record.vo2max = summary.physio?.vo2max
                record.recoveryMinutes = summary.physio?.recoveryMinutes
                record.performanceCondition = summary.physio?.performanceCondition
                record.samplesData = samples
                record.routeData = route
                record.structureData = structure
                record.workoutName = summary.structure.prescription?.name
                record.processingVersion = FITReaderConstants.processingVersion
                record.fitProcessed = true
                record.updatedAt = .now
                try modelContext.save()
                result.activityIds.insert(record.activityId)
                if wasProcessed {
                    result.reprocessed += 1
                } else {
                    result.processed += 1
                }
            case .skipped:
                break
            case .unavailable:
                record.processingVersion = FITReaderConstants.processingVersion
                record.fitProcessed = true
                record.updatedAt = .now
                try modelContext.save()
            case .rateLimited:
                result.stoppedByRateLimit = true
                return result
            }
            progress(Double(index + 1) / Double(queue.count))
        }
        return result
    }

    private func readFIT(activityId: Int64) async throws -> FITOutcome {
        do {
            let summary = try FITReader.read(zip: try await source.fitArchive(activityId: activityId))
            let encoder = JSONEncoder()
            return .read(
                summary: summary,
                samples: try encoder.encode(summary.samples),
                route: try encoder.encode(summary.route),
                structure: try encoder.encode(summary.structure)
            )
        } catch let error as GarminAPIError where SyncErrorPolicy.isCredentialFailure(error) {
            throw error
        } catch GarminAPIError.rateLimited(_) {
            return .rateLimited
        } catch let error as GarminAPIError where SyncErrorPolicy.isPermanentFITFailure(error) {
            return .unavailable
        } catch is FITReaderError {
            return .unavailable
        } catch {
            if SyncErrorPolicy.isCancellation(error) { throw CancellationError() }
            return .skipped
        }
    }
}
