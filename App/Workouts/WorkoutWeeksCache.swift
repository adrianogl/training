import Foundation
import Insights
import Storage
import TrainingCore

final class WorkoutWeeksCache {
    private var signature: Int?
    private var weeks: [WorkoutWeek] = []

    func weeks(records: [ActivityRecord], goals: [GoalSnapshot] = [], plannedKilometers: [Day: Double]) -> [WorkoutWeek] {
        let current = Self.signature(records, goals: goals)
        if current != signature {
            weeks = PerformanceTrace.measure("semanas da lista") { WorkoutListModel.weeks(records: records, goals: goals) }
            signature = current
        }
        return weeks.map { week in
            var planned = week
            planned.plannedKilometers = plannedKilometers[week.start]
            return planned
        }
    }

    static func signature(_ records: [ActivityRecord], goals: [GoalSnapshot] = []) -> Int {
        var hasher = Hasher()
        hasher.combine(records.count)
        hasher.combine(goals.map(\.id))
        for record in records {
            hasher.combine(record.activityId)
            hasher.combine(record.updatedAt)
            hasher.combine(record.scoreValue)
            hasher.combine(record.processingVersion)
            hasher.combine(record.bestEffortsVersion)
        }
        return hasher.finalize()
    }
}
