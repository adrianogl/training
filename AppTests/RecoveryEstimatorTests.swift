import Foundation
import GarminAPI
import Testing
import TrainingCore
@testable import trAIning

@Suite struct RecoveryEstimatorTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    @Test func hoursGrowWithEffectAndLowReadiness() {
        #expect(RecoveryEstimator.hours(aerobic: 4.2, anaerobic: 1, readiness: nil) == 54)
        #expect(RecoveryEstimator.hours(aerobic: 4.2, anaerobic: 3.2, readiness: 40) == 78)
        #expect(RecoveryEstimator.hours(aerobic: 2.5, anaerobic: nil, readiness: 80) == 18)
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try #require(Self.calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)))
    }

    private func session(_ day: Int, _ kind: SessionKind, _ title: String, km: Double = 10) -> PlannedSession {
        PlannedSession(day: Day(iso: String(format: "2026-11-%02d", day))!, title: title, kilometers: km, kind: kind)
    }

    private func longRun(end: Date) -> RecoveryRun {
        RecoveryRun(title: "Corrida Longo sáb 14/11", end: end, aerobicEffect: 4.6, anaerobicEffect: 0.5, typicalHour: 19, kind: .long, kilometers: 12.7, averageHeartRate: 165)
    }

    @Test func neverComparesWithOwnWorkoutNorWithPastOnes() throws {
        let end = try date(14, 18, 45)
        let sessions = [
            session(14, .long, "Longo 16 km", km: 16),
            session(13, .easy, "Rodagem"),
            session(16, .easy, "Rodagem 12 km", km: 12),
        ]

        let estimate = RecoveryEstimator.estimate(run: longRun(end: end), readiness: nil, sessions: sessions, now: try date(15, 11, 35), calendar: Self.calendar)

        #expect(estimate.upcoming.map(\.title) == ["Rodagem 12 km"])
        #expect(estimate.upcoming.allSatisfy { $0.start > estimate.now })
    }

    @Test func easyBeforeReadyIsRelaxedAndHardAfterReadyIsRecovered() throws {
        let end = try date(14, 18, 45)
        let sessions = [session(16, .easy, "Rodagem 12 km", km: 12), session(17, .threshold, "Limiar 8 x 1 km")]

        let estimate = RecoveryEstimator.estimate(run: longRun(end: end), readiness: nil, sessions: sessions, now: try date(15, 11, 35), calendar: Self.calendar)

        #expect(estimate.hours == 66)
        #expect(estimate.upcoming.map(\.status) == [.relaxed, .recovered])
        #expect(estimate.remainingHours == 49)
        #expect(estimate.advice?.contains("corte para 8 km") == true)
    }

    @Test func hardWorkoutJustBeforeReadyIsAlmostAndEarlierIsEarly() throws {
        let end = try date(9, 12)
        let run = RecoveryRun(title: "VO2", end: end, aerobicEffect: 3.0, anaerobicEffect: 0, typicalHour: 17, kind: .intervals)
        let ready = end.addingTimeInterval(30 * 3_600)

        #expect(RecoveryEstimator.status(kind: .long, hoursFromReady: -1) == .almost)
        #expect(RecoveryEstimator.status(kind: .long, hoursFromReady: -2) == .almost)
        #expect(RecoveryEstimator.status(kind: .long, hoursFromReady: -2.5) == .early)
        #expect(RecoveryEstimator.status(kind: .intervals, hoursFromReady: 0) == .recovered)
        #expect(RecoveryEstimator.status(kind: .easy, hoursFromReady: -20) == .relaxed)

        let estimate = RecoveryEstimator.estimate(run: run, readiness: nil, sessions: [session(10, .long, "Longo 16 km", km: 16)], now: end, calendar: Self.calendar)

        #expect(estimate.readyAt == ready)
        #expect(estimate.upcoming.first?.status == .almost)
        #expect(estimate.advice?.contains("1 h antes") == true)
    }

    @Test func usesTypicalHourOfWeekdayOrWeekend() throws {
        let saturday = try date(14, 8)
        let monday = try date(9, 19)
        let hours = RecoveryEstimator.typicalHours([saturday, monday, try date(10, 19), try date(11, 19)], calendar: Self.calendar)

        #expect(hours.weekday == 19)
        #expect(hours.weekend == 8)
    }
}
