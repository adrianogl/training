import Foundation
import GarminAPI
import Testing
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

    @Test func comparesWithNextPlannedWorkoutAtTypicalHour() throws {
        let end = try #require(Self.calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 9)))
        let run = RecoveryRun(title: "Longão", end: end, aerobicEffect: 4.2, anaerobicEffect: 0.5, typicalHour: 19)
        let planned = [
            PlannedWorkout(id: 1, day: "2026-11-16", title: "Intervalado", estimatedSeconds: nil, estimatedMeters: nil, steps: []),
            PlannedWorkout(id: 2, day: "2026-11-15", title: "Regenerativo", estimatedSeconds: nil, estimatedMeters: nil, steps: []),
        ]

        let estimate = RecoveryEstimator.estimate(run: run, readiness: 60, planned: planned, now: end.addingTimeInterval(27 * 3_600), calendar: Self.calendar)

        #expect(estimate.hours == 54)
        #expect(abs(estimate.progress - 0.5) < 0.01)
        #expect(estimate.next?.title == "Regenerativo")
        #expect(estimate.next?.gapHours == 34)
        #expect(estimate.next?.enough == false)
    }
}
