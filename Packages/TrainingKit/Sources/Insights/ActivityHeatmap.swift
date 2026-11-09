import Foundation
import Storage
import SwiftData
import TrainingCore

public enum HeatmapDefaults {
    public static let weeks = 26
}

public func activityHeatmap(context: ModelContext, today: Day, weeks: Int = HeatmapDefaults.weeks) throws -> [Day: Double] {
    let start = today.weekStart.adding(days: -(max(weeks, 1) - 1) * InsightsConstants.daysPerWeek)
    var km: [Day: Double] = [:]
    for activity in try fetchActivities(context, since: start, through: today) {
        guard let meters = activity.distance, meters > 0 else { continue }
        km[activityDay(activity), default: 0] += meters / InsightsConstants.metersPerKm
    }
    return km
}
