import Foundation
import TrainingCore

enum ActivityTime {
    static func parseLocal(_ value: String) -> Date? {
        let parts = value.split(whereSeparator: { $0 == " " || $0 == "T" })
        guard parts.count == 2, let day = Day(iso: String(parts[0])) else { return nil }
        let time = parts[1].split(separator: ":").compactMap { Int($0.prefix(2)) }
        guard time.count >= 2 else { return nil }
        let components = DateComponents(
            year: day.year, month: day.month, day: day.day,
            hour: time[0], minute: time[1], second: time.count > 2 ? time[2] : 0
        )
        return calendar.date(from: components)
    }

    static func day(of date: Date) -> Day {
        Day.today(in: calendar.timeZone, now: date)
    }

    static func startOfDay(_ day: Day) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .distantPast
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
}
