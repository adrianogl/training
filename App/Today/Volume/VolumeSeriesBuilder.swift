import Insights
import TrainingCore

enum VolumeSeriesBuilder {
    static func make(week: WeekVolume, planned: [Day: Double]) -> VolumeSeries {
        let weeks = week.recentWeeks
        let lastStart = weeks.last?.start
        let points = weeks.map { item in
            VolumePoint(start: item.start, kilometers: item.kilometers, plannedKm: planned[item.start].flatMap { $0 > 0 ? $0 : nil }, isCurrent: item.start == lastStart)
        }
        let closed = points.filter { !$0.isCurrent && $0.plannedKm != nil }
        let plan = closed.reduce(0) { $0 + ($1.plannedKm ?? 0) }
        let adherence = plan > 0 ? closed.reduce(0) { $0 + $1.kilometers } / plan : nil
        var projected: Double?
        if let adherence, let current = points.last, let currentPlan = current.plannedKm, currentPlan > current.kilometers {
            projected = current.kilometers + (currentPlan - current.kilometers) * min(adherence, 1)
        }
        return VolumeSeries(points: points, average4Weeks: week.average4Weeks, adherence: adherence, projectedKm: projected)
    }
}
