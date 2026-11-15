import Foundation
import TrainingCore

enum RecoveryEstimator {
    private typealias C = RecoveryConstants

    static func hours(aerobic: Double?, anaerobic: Double?, readiness: Int?) -> Int {
        var hours = C.baseHours.last { (aerobic ?? 0) >= $0.effect }?.hours ?? C.baseHours[0].hours
        if (anaerobic ?? 0) >= C.anaerobicHeavy { hours += C.anaerobicExtraHours }
        if let readiness {
            if readiness < C.lowReadiness { hours += C.lowReadinessExtraHours }
            if readiness >= C.goodReadiness { hours -= C.goodReadinessSavedHours }
        }
        return Int(hours)
    }

    static func estimate(run: RecoveryRun, readiness: Int?, sessions: [PlannedSession], now: Date, calendar: Calendar = .current) -> RecoveryEstimate {
        let hours = hours(aerobic: run.aerobicEffect, anaerobic: run.anaerobicEffect, readiness: readiness)
        let readyAt = run.end.addingTimeInterval(Double(hours) * C.secondsPerHour)
        let progress = min(max(now.timeIntervalSince(run.end) / (Double(hours) * C.secondsPerHour), 0), 1)
        let upcoming = upcoming(run: run, sessions: sessions, readyAt: readyAt, now: now, calendar: calendar)
        let lastEvent = upcoming.last?.start ?? readyAt
        let farthest = max(readyAt, lastEvent, now)
        let axisEnd = farthest.addingTimeInterval(farthest.timeIntervalSince(run.end) * C.axisMargin)
        return RecoveryEstimate(
            title: run.title,
            kind: run.kind,
            kilometers: run.kilometers,
            averageHeartRate: run.averageHeartRate,
            end: run.end,
            now: now,
            hours: hours,
            readyAt: readyAt,
            progress: progress,
            remainingHours: max(Int((readyAt.timeIntervalSince(now) / C.secondsPerHour).rounded()), 0),
            upcoming: upcoming,
            axisEnd: axisEnd,
            advice: advice(upcoming: upcoming, readyAt: readyAt, calendar: calendar)
        )
    }

    static func status(kind: SessionKind, hoursFromReady: Double) -> RecoveryStatus {
        guard kind.isHard else { return .relaxed }
        if hoursFromReady >= 0 { return .recovered }
        return hoursFromReady >= -C.almostHours ? .almost : .early
    }

    static func typicalHour(_ starts: [Date], weekend: Bool, calendar: Calendar = .current) -> Int? {
        let hours = starts
            .filter { isWeekend($0, calendar: calendar) == weekend }
            .map { calendar.component(.hour, from: $0) }
            .sorted()
        guard !hours.isEmpty else { return nil }
        return hours[hours.count / 2]
    }

    static func typicalHours(_ starts: [Date], calendar: Calendar = .current) -> (weekday: Int, weekend: Int?) {
        let weekend = typicalHour(starts, weekend: true, calendar: calendar)
        let weekday = typicalHour(starts, weekend: false, calendar: calendar) ?? weekend ?? C.defaultHour
        return (weekday, weekend)
    }

    private static func upcoming(run: RecoveryRun, sessions: [PlannedSession], readyAt: Date, now: Date, calendar: Calendar) -> [RecoveryNext] {
        let runDay = Day.today(in: calendar.timeZone, now: run.end)
        let limit = now.addingTimeInterval(Double(C.lookAheadDays) * C.secondsPerDay)
        return sessions
            .filter { !isOrigin($0, run: run, runDay: runDay) }
            .compactMap { session -> RecoveryNext? in
                let hour = isWeekend(session.day) ? (run.weekendHour ?? run.typicalHour) : run.typicalHour
                let components = DateComponents(year: session.day.year, month: session.day.month, day: session.day.day, hour: hour)
                guard let start = calendar.date(from: components), start > now, start > run.end, start <= limit else { return nil }
                let offset = start.timeIntervalSince(readyAt) / C.secondsPerHour
                return RecoveryNext(
                    title: session.title,
                    kind: session.kind,
                    kilometers: session.kilometers > 0 ? session.kilometers : nil,
                    start: start,
                    hoursFromReady: offset,
                    status: status(kind: session.kind, hoursFromReady: offset)
                )
            }
            .sorted { $0.start < $1.start }
            .prefix(C.maxUpcoming)
            .map { $0 }
    }

    private static func isOrigin(_ session: PlannedSession, run: RecoveryRun, runDay: Day) -> Bool {
        guard session.day == runDay else { return false }
        return session.title == run.title || run.kind == session.kind
    }

    private static func isWeekend(_ day: Day) -> Bool {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: day.chartDate)
        return weekday == C.saturday || weekday == C.sunday
    }

    private static func isWeekend(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == C.saturday || weekday == C.sunday
    }

    private static func advice(upcoming: [RecoveryNext], readyAt: Date, calendar: Calendar) -> String? {
        if let tight = upcoming.first(where: { $0.status == .almost || $0.status == .early }) {
            let gap = Int((-tight.hoursFromReady).rounded())
            let subject = C.kindSubject[tight.kind] ?? ""
            return String(format: tight.status == .almost ? C.adviceAlmostFormat : C.adviceEarlyFormat, subject, gap)
        }
        guard let first = upcoming.first, first.kind == .easy, first.start < readyAt else { return nil }
        var text = String(format: C.adviceEasyFormat, WeeklyReportBuilder.weekdayName(Day.today(in: calendar.timeZone, now: first.start)))
        if let km = first.kilometers { text += String(format: C.adviceEasyCutFormat, Int((km * C.easyCutShare).rounded())) }
        return text
    }
}
