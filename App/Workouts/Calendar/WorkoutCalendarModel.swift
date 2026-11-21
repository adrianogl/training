import Foundation
import GarminAPI
import TrainingCore

enum WorkoutCalendarModel {
    private typealias C = WorkoutCalendarConstants

    static func key(_ workout: StrengthWorkout) -> String {
        "\(workout.id)|\(workout.day)"
    }

    static func monthStart(_ day: Day) -> Day {
        Day(year: day.year, month: day.month, day: 1)
    }

    static func shift(_ month: Day, by months: Int) -> Day {
        let index = month.year * 12 + (month.month - 1) + months
        return Day(year: index / 12, month: index % 12 + 1, day: 1)
    }

    static func grid(month: Day) -> [Day] {
        let first = monthStart(month)
        let next = shift(first, by: 1)
        let start = first.weekStart
        let lastDay = next.adding(days: -1)
        let end = lastDay.weekStart.adding(days: 6)
        return (0...start.days(until: end)).map { start.adding(days: $0) }
    }

    static func monthEnd(_ month: Day) -> Day {
        shift(monthStart(month), by: 1).adding(days: -1)
    }

    static func plannedRange(month: Day, today: Day) -> ClosedRange<Day>? {
        let first = max(monthStart(month), today)
        let last = monthEnd(month)
        return first <= last ? first...last : nil
    }

    static func defaultSelection(month: Day, today: Day) -> Day {
        monthStart(today) == monthStart(month) ? today : monthStart(month)
    }

    static func days(rows: [WorkoutRowData], planned: [WorkoutPlannedItem], mfitIds: Set<String>) -> [String: WorkoutCalendarDay] {
        var result: [String: WorkoutCalendarDay] = [:]
        for row in rows {
            if row.isStrength {
                result[row.dayIso, default: WorkoutCalendarDay()].strength = true
            } else {
                result[row.dayIso, default: WorkoutCalendarDay()].ran = true
                result[row.dayIso, default: WorkoutCalendarDay()].kilometers += row.kilometers ?? 0
            }
        }
        for item in planned {
            switch item {
            case .run(let plan):
                result[plan.day, default: WorkoutCalendarDay()].plannedRun = true
            case .strength(let workout):
                if mfitIds.contains(key(workout)) {
                    result[workout.day, default: WorkoutCalendarDay()].mfit = true
                } else {
                    result[workout.day, default: WorkoutCalendarDay()].strength = true
                }
            }
        }
        return result
    }

    static func summary(rows: [WorkoutRowData], month: Day) -> WorkoutCalendarSummary {
        let prefix = String(monthStart(month).iso.prefix(7))
        let inMonth = rows.filter { $0.dayIso.hasPrefix(prefix) }
        let runs = inMonth.filter { !$0.isStrength }
        return WorkoutCalendarSummary(runs: runs.count, kilometers: runs.compactMap(\.kilometers).reduce(0, +), strength: inMonth.filter(\.isStrength).count)
    }

    static func title(_ month: Day) -> String {
        format(month, C.monthFormat).capitalizedFirst
    }

    static func dayTitle(_ day: Day) -> String {
        format(day, C.dayTitleFormat).capitalizedFirst
    }

    private static func format(_ day: Day, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = WorkoutConstants.locale
        formatter.dateFormat = pattern
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .now
        return formatter.string(from: date)
    }
}

private extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
