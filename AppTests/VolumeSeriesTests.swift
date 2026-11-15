import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct VolumeSeriesTests {
    private static let first = Day(iso: "2026-10-26")!

    private static func week(_ offset: Int, _ km: Double) -> WeekTotal {
        WeekTotal(start: first.adding(days: 7 * offset), kilometers: km)
    }

    private func volume(_ weeks: [WeekTotal]) -> WeekVolume {
        WeekVolume(perDay: [:], total: weeks.last?.kilometers ?? 0, lastWeek: 0, average4Weeks: 48.1, recentWeeks: weeks)
    }

    @Test func percentPerWeekAndAdherenceOfClosedWeeks() {
        let weeks = [Self.week(0, 30), Self.week(1, 63), Self.week(2, 59.7)]
        let planned = [weeks[0].start: 61.0, weeks[1].start: 69.0, weeks[2].start: 66.2]

        let series = VolumeSeriesBuilder.make(week: volume(weeks), planned: planned)

        #expect(series.points.map(\.percent) == [49, 91, 90])
        #expect(series.adherencePercent == 72)
    }

    @Test func projectionAddsRemainingPlanTimesAdherence() throws {
        let weeks = [Self.week(0, 30), Self.week(1, 63), Self.week(2, 59.7)]
        let planned = [weeks[0].start: 61.0, weeks[1].start: 69.0, weeks[2].start: 66.2]

        let series = VolumeSeriesBuilder.make(week: volume(weeks), planned: planned)

        let projected = try #require(series.projectedKm)
        #expect(abs(projected - (59.7 + 6.5 * (93.0 / 130.0))) < 0.01)
    }

    @Test func weeksWithoutPlanHaveNoPercentAndNoProjection() {
        let weeks = [Self.week(0, 40), Self.week(1, 55)]

        let series = VolumeSeriesBuilder.make(week: volume(weeks), planned: [:])

        #expect(series.points.map(\.percent) == [nil, nil])
        #expect(series.adherencePercent == nil)
        #expect(series.projectedKm == nil)
    }

    @Test func noProjectionWhenCurrentWeekAlreadyReachedPlan() {
        let weeks = [Self.week(0, 50), Self.week(1, 70)]
        let planned = [weeks[0].start: 60.0, weeks[1].start: 66.0]

        #expect(VolumeSeriesBuilder.make(week: volume(weeks), planned: planned).projectedKm == nil)
    }
}
