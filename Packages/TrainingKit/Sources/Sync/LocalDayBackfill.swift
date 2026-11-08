import Foundation
import Storage
import SwiftData

extension SyncEngine {
    func backfillLocalDays() throws {
        let missing = Date.distantPast
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.localDay == nil && $0.start > missing })
        let records = try modelContext.fetch(descriptor)
        guard !records.isEmpty else { return }
        for record in records {
            record.localDay = ActivityTime.day(of: record.start).iso
        }
        try modelContext.save()
    }
}
