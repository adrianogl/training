import Foundation
import TrainingCore

extension StrengthPlan {
    public var lengthInDays: Int {
        start.days(until: end) + 1
    }

    public var totalWeeks: Int {
        max(1, (lengthInDays + StrengthPlanConstants.daysPerWeek - 1) / StrengthPlanConstants.daysPerWeek)
    }

    public var weekdays: Set<Int> {
        Set(sessions.map(\.weekday))
    }

    public func week(on day: Day) -> Int {
        min(max(start.days(until: day) / StrengthPlanConstants.daysPerWeek + 1, 1), totalWeeks)
    }

    public func doneCount(doneDays: Set<Day>) -> Int {
        let weekdays = weekdays
        return doneDays.filter { isActive(on: $0) && weekdays.contains(Self.weekday(of: $0)) }.count
    }

    public static func firstSessionDay(weekdays: Set<Int>, from day: Day) -> Day? {
        guard !weekdays.isEmpty else { return nil }
        return (0..<StrengthPlanConstants.daysPerWeek).map { day.adding(days: $0) }.first { weekdays.contains(weekday(of: $0)) }
    }

    public func repeated(after today: Day, now: Date = .now) -> StrengthPlan {
        let first = today.adding(days: 1)
        let newStart = Self.firstSessionDay(weekdays: weekdays, from: first) ?? first
        let newValidity: StrengthPlanValidity = switch validity {
        case .weeks(let count): .weeks(count)
        case .untilDate, .untilRace: .untilDate(newStart.adding(days: lengthInDays - 1))
        }
        return StrengthPlan(objective: objective, sessions: sessions, start: newStart, validity: newValidity, builder: builder, createdAt: now)
    }

    static func weekday(of day: Day) -> Int {
        day.weekStart.days(until: day) + 1
    }
}
