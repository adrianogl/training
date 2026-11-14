import Foundation
import Storage

struct FITQueueSplit {
    let immediate: [ActivityRecord]
    let deferred: [ActivityRecord]

    init(queue: [ActivityRecord], deferringOlderThanDays days: Int?, now: Date) {
        guard let days else {
            immediate = queue
            deferred = []
            return
        }
        let cutoff = now.addingTimeInterval(-Double(days) * SyncConstants.secondsPerDay)
        immediate = queue.filter { $0.start >= cutoff }
        deferred = queue.filter { $0.start < cutoff }
    }
}
