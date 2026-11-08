import Foundation
import GarminAPI
import Storage
import TrainingCore

extension SyncEngine {
    func syncActivities(
        from: Day?,
        startAt initialStart: Int,
        incrementalCutoff: Date?,
        state: SyncState,
        tracksResume: Bool
    ) async throws -> Set<Int64> {
        let pageSize = SyncConstants.activityPageSize
        var touched: Set<Int64> = []
        var start = initialStart
        while true {
            try Task.checkCancellation()
            let page = try await source.activities(start: start, limit: pageSize, from: from, to: nil)
            for dto in page {
                try upsertActivity(dto)
                touched.insert(dto.activityId)
            }
            if tracksResume {
                state.resumeActivityStart = start + pageSize
            }
            try modelContext.save()
            if page.count < pageSize { break }
            if let incrementalCutoff,
               let oldest = page.compactMap({ $0.startTimeLocal.flatMap(ActivityTime.parseLocal) }).min(),
               oldest < incrementalCutoff {
                break
            }
            start += pageSize
        }
        return touched
    }
}
