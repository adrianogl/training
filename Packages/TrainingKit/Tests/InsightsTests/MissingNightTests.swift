import Foundation
import SwiftData
import Testing
@testable import Insights

@Suite struct MissingNightTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private static func at(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: hour))!
    }

    private static func context() throws -> ModelContext {
        var models: [any PersistentModel] = [daily(daysAgo: 0, bodyBattery: 40, stress: 30)]
        for offset in 1...10 {
            models.append(daily(daysAgo: offset, hrv: 60, balanced: 50...70, sleepScore: 80, bodyBattery: 70))
        }
        return try makeContext(models)
    }

    @Test func dayWithoutNightDataAfterTenIsMissingNight() throws {
        let summary = try todaySummary(context: try Self.context(), today: fixtureToday, now: Self.at(hour: 11), calendar: Self.calendar)

        #expect(summary.readinessFromYesterday)
        #expect(summary.readinessMissingNight == true)
    }

    @Test func beforeTenItIsStillWaitingForTheNight() throws {
        let summary = try todaySummary(context: try Self.context(), today: fixtureToday, now: Self.at(hour: 8), calendar: Self.calendar)

        #expect(summary.readinessFromYesterday)
        #expect(summary.readinessMissingNight == false)
    }

    @Test func dayWithNightDataIsNotMissingNight() throws {
        var models: [any PersistentModel] = [daily(daysAgo: 0, hrv: 62, balanced: 50...70, sleepScore: 75, bodyBattery: 70)]
        for offset in 1...10 {
            models.append(daily(daysAgo: offset, hrv: 60, balanced: 50...70, sleepScore: 80, bodyBattery: 70))
        }
        let summary = try todaySummary(context: try makeContext(models), today: fixtureToday, now: Self.at(hour: 11), calendar: Self.calendar)

        #expect(!summary.readinessFromYesterday)
        #expect(summary.readinessMissingNight == false)
    }
}
