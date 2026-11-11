import Foundation
import Storage
import SwiftData
import TrainingCore

struct ThresholdTimeline {
    let entries: [(day: String, heartRate: Int)]
    let fallback: Int?

    init(sport: String, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<ThresholdHistoryRecord>(
            predicate: #Predicate { $0.sport == sport },
            sortBy: [SortDescriptor(\.day)]
        )
        entries = try context.fetch(descriptor).map { ($0.day, $0.heartRate) }
        var zones = FetchDescriptor<HeartRateZonesRecord>(predicate: #Predicate { $0.sport == sport })
        zones.fetchLimit = 1
        fallback = try context.fetch(zones).first?.lactateThresholdHeartRate
    }

    func heartRate(on day: Day) -> Int? {
        let iso = day.iso
        return (entries.last { $0.day <= iso } ?? entries.first)?.heartRate ?? fallback
    }
}
