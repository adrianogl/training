import Foundation
import TrainingCore

enum WeeklyReportBuilder {
    private typealias C = WeeklyReportConstants

    static func reportWeek(today: Day, calendar: Calendar = .current) -> (start: Day, isCurrent: Bool)? {
        switch calendar.component(.weekday, from: today.chartDate) {
        case C.sunday: (today.weekStart, true)
        case C.monday, C.tuesday: (today.weekStart.adding(days: -7), false)
        default: nil
        }
    }

    static func report(start: Day, isCurrent: Bool, runs: [ReportRun], plannedKm: Double?, race: (name: String, days: Int)?) -> WeeklyReport {
        let done = runs.reduce(0) { $0 + $1.kilometers }
        let planned = plannedKm.flatMap { $0 > 0 ? $0 : nil }
        let adherence = planned.map { min(done / $0, 1.5) }
        let best = runs.filter { $0.score != nil }.max { ($0.score ?? 0) < ($1.score ?? 0) }
        let headline = planned.map { String(format: C.headlinePlanFormat, km(done), km($0)) }
            ?? String(format: C.headlineFormat, km(done), runs.count)
        var text = ""
        if let planned {
            text = done >= planned * C.completeShare ? C.completeText : String(format: C.shortFormat, km(planned - done))
        }
        if let best, let score = best.score { text += String(format: C.bestFormat, best.title, score) }
        if let race { text += String(format: C.raceFormat, race.name, race.days) }
        return WeeklyReport(
            start: start,
            isCurrentWeek: isCurrent,
            doneKm: done,
            runs: runs.count,
            plannedKm: planned,
            adherence: adherence,
            best: best,
            headline: headline,
            text: text.trimmingCharacters(in: .whitespaces),
            notification: [headline + ".", text].filter { !$0.isEmpty }.joined(separator: " ")
        )
    }

    static func nextSunday(after now: Date, calendar: Calendar = .current) -> Date? {
        calendar.nextDate(after: now, matching: DateComponents(hour: C.notificationHour, minute: 0, weekday: C.sunday), matchingPolicy: .nextTime)
    }

    private static func km(_ value: Double) -> String {
        TodayText.decimal(value, fractionDigits: value.rounded() == value ? 0 : 1)
    }
}
