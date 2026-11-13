import Foundation
import Storage
import TrainingCore
import WorkoutAnalysis

enum WorkoutListModel {
    static func rows(records: [ActivityRecord]) -> [WorkoutRowData] {
        records
            .filter { ActivityTypeKey.isRun($0.typeKey) }
            .sorted { $0.start > $1.start }
            .map(row)
    }

    static func weeks(records: [ActivityRecord]) -> [WorkoutWeek] {
        var order: [Day] = []
        var grouped: [Day: [WorkoutRowData]] = [:]
        for row in rows(records: records) {
            if grouped[row.weekStart] == nil { order.append(row.weekStart) }
            grouped[row.weekStart, default: []].append(row)
        }
        return order.map { start in
            let rows = grouped[start] ?? []
            return WorkoutWeek(start: start, kilometers: rows.reduce(0) { $0 + ($1.kilometers ?? 0) }, rows: rows)
        }
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
        let km = TodayText.decimal(week.kilometers, fractionDigits: 1)
        return week.rows.count == 1
            ? String(format: WorkoutConstants.weekSummarySingular, km)
            : String(format: WorkoutConstants.weekSummaryFormat, km, week.rows.count)
    }

    static func row(_ record: ActivityRecord) -> WorkoutRowData {
        let distance = record.distance.flatMap { $0 > 0 ? $0 : nil }
        let duration = movingSeconds(record)
        let isRun = ActivityTypeKey.isRun(record.typeKey)
        return WorkoutRowData(
            activityId: record.activityId,
            title: record.workoutName ?? record.name,
            dateText: dateText(record.start),
            distanceText: distance.map(distanceText),
            durationText: duration.map(clockText),
            paceText: isRun ? pace(distance: distance, duration: duration).map { paceText(secondsPerKilometer: $0) } : nil,
            hasPrescription: record.workoutName != nil,
            score: isRun ? record.scoreValue : nil,
            kilometers: distance.map { $0 / WorkoutConstants.metersPerKilometer },
            zoneShares: zoneShares(record.zoneSeconds),
            weekStart: Day.today(now: record.start).weekStart
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
