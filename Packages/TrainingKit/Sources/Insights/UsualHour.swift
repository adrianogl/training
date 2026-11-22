import Foundation
import TrainingCore

private typealias C = UsualHourConstants

public enum UsualHour {
    public static func hour(for date: Date, long: Bool, runs: [UsualHourRun], now: Date, calendar: Calendar) -> Int {
        source(for: date, long: long, runs: runs, now: now, calendar: calendar).hour
    }

    public static func source(
        for date: Date, long: Bool, runs: [UsualHourRun], now: Date, calendar: Calendar
    ) -> (hour: Int, source: UsualHourSource) {
        func within(_ days: Int) -> [UsualHourRun] {
            runs.filter { $0.start < now && $0.start >= now.addingTimeInterval(-Double(days) * C.secondsPerDay) }
        }
        if long, let hour = median(within(C.longWindowDays).filter(\.isLong), minimum: C.minimumLongRuns, calendar: calendar) {
            return (hour, .longRuns)
        }
        let weekend = calendar.isDateInWeekend(date)
        let window = weekend ? C.weekendWindowDays : C.weekdayWindowDays
        let sameKind = within(window).filter { calendar.isDateInWeekend($0.start) == weekend }
        if let hour = median(sameKind, minimum: C.minimumDayRuns, calendar: calendar) {
            return (hour, weekend ? .weekend : .weekday)
        }
        if let hour = median(within(C.allWindowDays), minimum: 1, calendar: calendar) { return (hour, .allRuns) }
        return (C.defaultHour, .fallback)
    }

    public static func median(_ runs: [UsualHourRun], minimum: Int, calendar: Calendar) -> Int? {
        guard runs.count >= max(minimum, 1) else { return nil }
        let hours = runs.map { calendar.component(.hour, from: $0.start) }.sorted()
        return hours[(hours.count - 1) / 2]
    }
}
