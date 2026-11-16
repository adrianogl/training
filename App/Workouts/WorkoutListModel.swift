import Foundation
import GarminAPI
import Storage
import TrainingCore
import WorkoutAnalysis

enum WorkoutListModel {
    static func rows(records: [ActivityRecord]) -> [WorkoutRowData] {
        records
            .filter { ActivityTypeKey.isRun($0.typeKey) || ActivityTypeKey.isStrength($0.typeKey) }
            .sorted { $0.start > $1.start }
            .map(row)
    }

    static func weeks(records: [ActivityRecord], plannedKilometers: [Day: Double] = [:]) -> [WorkoutWeek] {
        var order: [Day] = []
        var grouped: [Day: [WorkoutRowData]] = [:]
        for row in rows(records: records) {
            if grouped[row.weekStart] == nil { order.append(row.weekStart) }
            grouped[row.weekStart, default: []].append(row)
        }
        return order.map { start in
            let rows = grouped[start] ?? []
            let runs = rows.filter { !$0.isStrength }
            return WorkoutWeek(
                start: start,
                kilometers: runs.reduce(0) { $0 + ($1.kilometers ?? 0) },
                rows: rows,
                runCount: runs.count,
                plannedKilometers: plannedKilometers[start],
                strengthCount: rows.count - runs.count
            )
        }
    }

    static func filtered(_ weeks: [WorkoutWeek], by filter: WorkoutKindFilter) -> [WorkoutWeek] {
        guard filter != .all else { return weeks }
        return weeks.compactMap { week in
            let rows = week.rows.filter { matches($0, filter: filter) }
            guard !rows.isEmpty else { return nil }
            return WorkoutWeek(start: week.start, kilometers: week.kilometers, rows: rows, runCount: week.runCount, plannedKilometers: week.plannedKilometers, strengthCount: week.strengthCount)
        }
    }

    static func matches(_ row: WorkoutRowData, filter: WorkoutKindFilter) -> Bool {
        switch filter {
        case .all: true
        case .run: !row.isStrength
        case .strength: row.isStrength
        }
    }

    static func plannedKilometers(planned: [PlannedWorkout], cached: [String: Double]) -> [Day: Double] {
        var weeks: [Day: Double] = [:]
        for (iso, km) in cached where km > 0 {
            if let start = Day(iso: iso) { weeks[start] = km }
        }
        var fetched: [Day: Double] = [:]
        for plan in planned {
            guard let start = Day(iso: plan.day)?.weekStart, let meters = plan.estimatedMeters, meters > 0 else { continue }
            fetched[start, default: 0] += meters / WorkoutConstants.metersPerKilometer
        }
        weeks.merge(fetched) { _, new in new }
        return weeks
    }

    static func visiblePlanned(planned: [PlannedWorkout], rows: [WorkoutRowData], from today: String = "") -> PlannedVisibility {
        let byDay = Dictionary(grouping: rows, by: \.dayIso)
        var fromPlan: Set<Int64> = []
        var visible: [PlannedWorkout] = []
        for plan in planned {
            let sameDay = byDay[plan.day] ?? []
            let match = sameDay.first { row in row.names.contains { $0.caseInsensitiveCompare(plan.title) == .orderedSame } }
                ?? (sameDay.count == 1 ? sameDay.first : nil)
            if let match {
                fromPlan.insert(match.activityId)
            } else if plan.day >= today {
                visible.append(plan)
            }
        }
        return PlannedVisibility(visible: visible.sorted { $0.day > $1.day }, fromPlanIds: fromPlan)
    }

    static func weekLabel(_ start: Day) -> String {
        let end = start.adding(days: 6)
        let formatter = DateFormatter()
        formatter.locale = WorkoutConstants.locale
        formatter.dateFormat = start.month == end.month ? WorkoutConstants.weekDayFormat : WorkoutConstants.weekMonthFormat
        let first = formatter.string(from: start.chartDate)
        formatter.dateFormat = WorkoutConstants.weekMonthFormat
        let last = formatter.string(from: end.chartDate)
        return String(format: WorkoutConstants.weekRangeFormat, first, last).replacingOccurrences(of: ".", with: "")
    }

    static func weekSummary(_ week: WorkoutWeek) -> String {
        guard week.runCount > 0 else { return String(format: WorkoutConstants.weekStrengthOnlyFormat, week.strengthCount) }
        let runs = runSummary(week)
        return week.strengthCount > 0 ? String(format: WorkoutConstants.weekStrengthFormat, runs, week.strengthCount) : runs
    }

    private static func runSummary(_ week: WorkoutWeek) -> String {
        let km = TodayText.decimal(week.kilometers, fractionDigits: 1)
        if week.plannedProgress != nil, let planned = week.plannedKilometers {
            let plannedText = TodayText.decimal(planned, fractionDigits: 1)
            return week.runCount == 1
                ? String(format: WorkoutConstants.weekPlannedSingular, km, plannedText)
                : String(format: WorkoutConstants.weekPlannedFormat, km, plannedText, week.runCount)
        }
        return week.runCount == 1
            ? String(format: WorkoutConstants.weekSummarySingular, km)
            : String(format: WorkoutConstants.weekSummaryFormat, km, week.runCount)
    }

    static func row(_ record: ActivityRecord) -> WorkoutRowData {
        let distance = record.distance.flatMap { $0 > 0 ? $0 : nil }
        let duration = movingSeconds(record)
        let isRun = ActivityTypeKey.isRun(record.typeKey)
        return WorkoutRowData(
            activityId: record.activityId,
            title: record.workoutName ?? record.name,
            names: [record.workoutName, record.name].compactMap { $0 },
            dayIso: Day.today(now: record.start).iso,
            dateText: dateText(record.start),
            distanceText: distance.map(distanceText),
            durationText: duration.map(clockText),
            paceText: isRun ? pace(distance: distance, duration: duration).map { paceText(secondsPerKilometer: $0) } : nil,
            hasPrescription: record.workoutName != nil,
            score: isRun ? record.scoreValue : nil,
            kilometers: distance.map { $0 / WorkoutConstants.metersPerKilometer },
            zoneShares: zoneShares(record.zoneSeconds),
            weekStart: Day.today(now: record.start).weekStart,
            isStrength: ActivityTypeKey.isStrength(record.typeKey)
        )
    }

    private static func zoneShares(_ seconds: [Double]) -> [Double] {
        let total = seconds.reduce(0, +)
        return total > 0 ? seconds.map { $0 / total } : []
    }

    private static func pace(distance: Double?, duration: Double?) -> Double? {
        guard let distance, let duration else { return nil }
        return duration / (distance / WorkoutConstants.metersPerKilometer)
    }

    static func paceText(secondsPerKilometer: Double) -> String {
        "\(clockText(secondsPerKilometer)) \(WorkoutConstants.paceUnit)"
    }

    static func paceClock(metersPerSecond speed: Double?) -> String? {
        guard let speed, speed > 0 else { return nil }
        return clockText(WorkoutConstants.metersPerKilometer / speed)
    }

    static func paceText(metersPerSecond speed: Double?) -> String? {
        guard let speed, speed > 0 else { return nil }
        return paceText(secondsPerKilometer: WorkoutConstants.metersPerKilometer / speed)
    }

    static func movingSeconds(_ record: ActivityRecord) -> Double? {
        (record.movingDuration.flatMap { $0 > 0 ? $0 : nil } ?? record.duration).flatMap { $0 > 0 ? $0 : nil }
    }

    static func distanceText(_ meters: Double) -> String {
        "\(WorkoutFormat.kilometers(meters)) \(WorkoutConstants.distanceUnit)"
    }

    static func clockText(_ seconds: Double) -> String {
        WorkoutFormat.clock(seconds)
    }

    static func dateText(_ date: Date) -> String {
        guard date > .distantPast else { return "" }
        return date.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()
                .locale(WorkoutConstants.locale)
        )
    }
}
