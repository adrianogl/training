import Foundation
import TrainingCore

public struct StrengthPlan: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var objective: StrengthObjective
    public var sessions: [TrainerStrengthSession]
    public var start: Day
    public var validity: StrengthPlanValidity
    public var builder: StrengthPlanBuilder
    public var createdAt: Date
    public var endedNotifiedAt: Date?
    public var migrated: Bool

    public init(
        id: UUID = UUID(), objective: StrengthObjective, sessions: [TrainerStrengthSession], start: Day,
        validity: StrengthPlanValidity, builder: StrengthPlanBuilder, createdAt: Date = .now,
        endedNotifiedAt: Date? = nil, migrated: Bool = false
    ) {
        self.id = id
        self.objective = objective
        self.sessions = sessions
        self.start = start
        self.validity = validity
        self.builder = builder
        self.createdAt = createdAt
        self.endedNotifiedAt = endedNotifiedAt
        self.migrated = migrated
    }

    public var end: Day {
        switch validity {
        case .weeks(let count): start.adding(days: count * StrengthPlanConstants.daysPerWeek - 1)
        case .untilDate(let day): day
        case .untilRace(_, let raceDay): raceDay.adding(days: -1)
        }
    }

    public func isActive(on day: Day) -> Bool {
        start <= day && day <= end
    }

    public func lastSessionDay() -> Day? {
        sessionDays().last
    }

    public func plannedCount() -> Int {
        sessionDays().count
    }

    private func sessionDays() -> [Day] {
        let weekdays = Set(sessions.map(\.weekday))
        let span = start.days(until: end)
        guard span >= 0 else { return [] }
        return (0...span).map { start.adding(days: $0) }.filter { day in
            weekdays.contains(day.weekStart.days(until: day) + 1)
        }
    }
}
