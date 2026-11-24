import Foundation
import Storage
import WorkoutAnalysis

final class RecordTimelineCache {
    private var signature: Int?
    private var cached: [Int64: RunRecords] = [:]

    func timeline(records: [ActivityRecord]) -> [Int64: RunRecords] {
        let current = WorkoutWeeksCache.signature(records)
        if current != signature {
            cached = PersonalRecords.timeline(PersonalRecords.runEfforts(records))
            signature = current
        }
        return cached
    }
}
