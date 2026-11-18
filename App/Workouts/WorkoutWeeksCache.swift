import Foundation
import Storage
import TrainingCore

final class WorkoutWeeksCache {
    private var signature: Int?
    private var weeks: [WorkoutWeek] = []

    func weeks(records: [ActivityRecord], plannedKilometers: [Day: Double]) -> [WorkoutWeek] {
        let current = Self.signature(records)
        if current != signature {
            weeks = PerformanceTrace.measure("semanas da lista") { WorkoutListModel.weeks(records: records) }
            signature = current
        }
        return weeks.map { week in
            var planned = week
            planned.plannedKilometers = plannedKilometers[week.start]
            return planned
        }
    }

    static func signature(_ records: [ActivityRecord]) -> Int {
        var hasher = Hasher()
        hasher.combine(records.count)
        for record in records {
            hasher.combine(record.activityId)
            hasher.combine(record.updatedAt)
            hasher.combine(record.scoreValue)
            hasher.combine(record.processingVersion)
        }
        return hasher.finalize()
    }
}
