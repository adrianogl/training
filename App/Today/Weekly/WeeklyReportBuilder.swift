import Foundation
import TrainingCore
import WorkoutAnalysis

enum WeeklyReportBuilder {
    private typealias C = WeeklyReportConstants

    static func reportWeek(today: Day, calendar: Calendar = .current) -> (start: Day, isCurrent: Bool)? {
        switch calendar.component(.weekday, from: today.chartDate) {
        case C.sunday: (today.weekStart, true)
        case C.monday, C.tuesday: (today.weekStart.adding(days: -7), false)
        default: nil
        }
    }

    static func shownWeek(today: Day, calendar: Calendar = .current) -> ShownWeek {
        guard let week = reportWeek(today: today, calendar: calendar) else {
            return ShownWeek(start: today.weekStart, isCurrent: true, isClosed: false)
        }
        return ShownWeek(start: week.start, isCurrent: week.isCurrent, isClosed: true)
    }

    static func report(
        start: Day,
        isCurrent: Bool,
        runs: [ReportRun],
        plannedKm: Double?,
        race: ReportRace?,
        sessions: [PlannedSession] = [],
        today: Day? = nil
    ) -> WeeklyReport {
        let weekSessions = sessions.filter { $0.day >= start && $0.day <= start.adding(days: 6) }
        let done = runs.reduce(0) { $0 + $1.kilometers }
        let sessionKm = weekSessions.reduce(0) { $0 + $1.kilometers }
        let planned = (plannedKm ?? (sessionKm > 0 ? sessionKm : nil)).flatMap { $0 > 0 ? $0 : nil }
        let adherence = planned.map { min(done / $0, C.adherenceCap) }
        let missing = planned.flatMap { $0 - done > C.missingThreshold ? $0 - done : nil }
        let currentDay = today ?? start.adding(days: 7)
        let days = (0..<7).map { column(start.adding(days: $0), runs: runs, sessions: weekSessions, today: currentDay) }
        let isComplete = planned.map { done >= $0 && days.allSatisfy { [.done, .off].contains($0.state) } } ?? false
        let best = runs.filter { $0.score != nil }.max { ($0.score ?? 0) < ($1.score ?? 0) }
        let headline = planned.map { String(format: C.headlinePlanFormat, km(done), km($0)) }
            ?? String(format: C.headlineFormat, km(done), runs.count)
        var text = ""
        if isComplete {
            text = C.completeText
        } else if let missing {
            text = String(format: C.shortFormat, km(missing))
        }
        if let best, let score = best.score { text += String(format: C.bestFormat, cleanTitle(best.title), score) }
        if let race { text += String(format: C.raceFormat, race.name, race.days) }
        return WeeklyReport(
            start: start,
            isCurrentWeek: isCurrent,
            doneKm: done,
            runs: runs.count,
            plannedKm: planned,
            adherence: adherence,
            percent: adherence.map { Int(($0 * 100).rounded()) },
            missingKm: missing,
            isComplete: isComplete,
            days: days,
            runCount: weekSessions.isEmpty ? nil : ReportCount(done: runs.count, planned: weekSessions.count),
            quality: quality(runs: runs, sessions: weekSessions),
            long: long(runs: runs, sessions: weekSessions),
            best: best,
            bestCard: best.flatMap(bestCard),
            race: race,
            note: note(start: start, days: days, race: race),
            headline: headline,
            text: text.trimmingCharacters(in: .whitespaces),
            notification: [headline + ".", text.trimmingCharacters(in: .whitespaces)].filter { !$0.isEmpty }.joined(separator: " ")
        )
    }

    static func cleanTitle(_ title: String) -> String {
        var words: [Substring] = []
        for word in title.split(separator: " ") where word.lowercased() != words.last?.lowercased() {
            words.append(word)
        }
        let joined = words.joined(separator: " ")
        guard let regex = try? NSRegularExpression(pattern: C.datePattern, options: .caseInsensitive) else { return joined }
        let range = NSRange(joined.startIndex..., in: joined)
        return regex.stringByReplacingMatches(in: joined, range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
    }

    static func dayLabel(_ day: Day) -> String {
        "\(weekday(day)) \(day.day)"
    }

    static func race(name: String, days: Int, today: Day, predictionSeconds: Double?) -> ReportRace {
        ReportRace(name: name, days: days, day: today.adding(days: days), prediction: predictionSeconds.map { TodayText.goalClock($0) })
    }

    static func nextSunday(after now: Date, calendar: Calendar = .current) -> Date? {
        calendar.nextDate(after: now, matching: DateComponents(hour: C.notificationHour, minute: 0, weekday: C.sunday), matchingPolicy: .nextTime)
    }

    private static func column(_ day: Day, runs: [ReportRun], sessions: [PlannedSession], today: Day) -> WeeklyDay {
        let dayRuns = runs.filter { $0.day == day.iso }
        let done = dayRuns.reduce(0) { $0 + $1.kilometers }
        let daySessions = sessions.filter { $0.day == day }
        let plannedKm = daySessions.reduce(0) { $0 + $1.kilometers }
        let kind = dayRuns.max { $0.kilometers < $1.kilometers }?.kind ?? daySessions.first?.kind
        let state: WeeklyDayState
        if done > 0 {
            state = plannedKm > 0 && done < plannedKm * C.completeShare ? .partial : .done
        } else if !daySessions.isEmpty {
            state = day < today ? .missed : .pending
        } else {
            state = .off
        }
        return WeeklyDay(
            day: day,
            weekday: weekday(day),
            plannedKm: plannedKm > 0 ? plannedKm : nil,
            doneKm: done > 0 ? done : nil,
            kind: kind,
            label: kind.flatMap { C.kindLabels[$0] } ?? (state == .off ? C.dayOff : nil),
            state: state
        )
    }

    private static func quality(runs: [ReportRun], sessions: [PlannedSession]) -> ReportCount? {
        let planned = sessions.filter { $0.kind.isQuality }
        guard !planned.isEmpty else { return nil }
        let onTarget = planned.filter { session in
            let km = runs.filter { $0.day == session.day.iso }.reduce(0) { $0 + $1.kilometers }
            return km >= session.kilometers * C.completeShare
        }
        return ReportCount(done: onTarget.count, planned: planned.count)
    }

    private static func long(runs: [ReportRun], sessions: [PlannedSession]) -> ReportLong? {
        guard let session = sessions.filter({ $0.kind == .long }).max(by: { $0.kilometers < $1.kilometers }) else { return nil }
        let km = runs.filter { $0.day == session.day.iso }.reduce(0) { $0 + $1.kilometers }
        return ReportLong(doneKm: km, plannedKm: session.kilometers)
    }

    private static func bestCard(_ run: ReportRun) -> ReportBest? {
        guard let score = run.score else { return nil }
        let name = cleanTitle(run.title)
        let title = run.day.flatMap(Day.init(iso:)).map { String(format: C.bestNameFormat, name, dayLabel($0)) } ?? name
        var detail = String(format: "%@ km", TodayText.decimal(run.kilometers, fractionDigits: 1))
        if let pace = run.paceSeconds { detail = String(format: C.bestDetailFormat, TodayText.decimal(run.kilometers, fractionDigits: 1), WorkoutFormat.clock(pace)) }
        return ReportBest(title: title, detail: detail, score: score)
    }

    private static func note(start: Day, days: [WeeklyDay], race: ReportRace?) -> String {
        let missed = days.filter { $0.state == .missed }.map {
            String(format: C.missedItemFormat, C.kindNouns[$0.kind ?? .easy] ?? "", weekdayName($0.day))
        }
        let stopped = days.first { $0.state == .partial && $0.kind == .long }?.doneKm
            .map { String(format: C.longStoppedFormat, TodayText.decimal($0, fractionDigits: 1)) }
        var sentence = ""
        if !missed.isEmpty {
            sentence = String(format: missed.count == 1 ? C.missedSingularFormat : C.missedPluralFormat, missed.joined(separator: C.andJoin))
        }
        if let stopped {
            sentence = sentence.isEmpty ? stopped.prefix(1).uppercased() + stopped.dropFirst() : sentence + C.andJoin + stopped
        }
        var result = sentence.isEmpty ? "" : sentence + "."
        let nextStart = start.adding(days: 7)
        if let day = race?.day, day >= nextStart, day <= nextStart.adding(days: 6) {
            result += (result.isEmpty ? "" : " ") + String(format: C.raceNote, weekdayName(day))
        }
        return result
    }

    private static func weekday(_ day: Day) -> String {
        C.weekdays[Calendar(identifier: .gregorian).component(.weekday, from: day.chartDate) - 1]
    }

    static func weekdayName(_ day: Day) -> String {
        C.weekdayNames[Calendar(identifier: .gregorian).component(.weekday, from: day.chartDate) - 1]
    }

    private static func km(_ value: Double) -> String {
        TodayText.decimal(value, fractionDigits: value.rounded() == value ? 0 : 1)
    }
}
