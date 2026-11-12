import Foundation
import Storage
import SwiftData
import TrainingCore

struct ThresholdTimeline {
    let entries: [(day: String, heartRate: Int)]
    let fallback: Int?

    init(in context: ModelContext) throws {
        let sport = SyncConstants.fitThresholdSport
        let descriptor = FetchDescriptor<ThresholdHistoryRecord>(
            predicate: #Predicate { $0.sport == sport },
            sortBy: [SortDescriptor(\.day)]
        )
        entries = try context.fetch(descriptor).map { ($0.day, $0.heartRate) }
        fallback = try runningZonesRecord(in: context)?.lactateThresholdHeartRate
    }

    func heartRate(on day: Day) -> Int? {
        let iso = day.iso
        return (entries.last { $0.day <= iso } ?? entries.first)?.heartRate ?? fallback
    }
}
