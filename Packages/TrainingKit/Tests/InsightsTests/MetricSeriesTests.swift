import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Insights

@Suite struct MetricSeriesTests {
    @Test(arguments: [MetricKind.vo2max, .hrv])
    func metricSeriesHasMovingAverageAndProjection(_ kind: MetricKind) throws {
        var models: [any PersistentModel] = []
        for offset in 0...120 {
            let value = 50 + 0.05 * Double(120 - offset) + (offset.isMultiple(of: 3) ? 1 : -1)
            models.append(run(id: Int64(offset + 1), daysAgo: offset, vo2max: value))
            let band: ClosedRange<Double> = offset == 0 ? 55...68 : 40...60
            models.append(daily(daysAgo: offset, hrv: value, balanced: band))
        }
        models.append(race(name: "Prova", inDays: 30))
        let context = try makeContext(models)

        let series = try metricSeries(kind, context: context, today: fixtureToday, period: .sixMonths)

        #expect(series.kind == kind)
        #expect(series.points.count == 121)
        #expect(series.movingAverage7.count == series.points.count)
        #expect(series.points.first?.0 == daysAgo(120))
        #expect(series.points.last?.0 == fixtureToday)
        #expect(series.projection.count == 60)
        #expect(series.projection.first?.day == fixtureToday.adding(days: 1))
        let raceDay = try #require(series.raceDayValue)
        #expect(abs(raceDay - series.projection[29].mid) < 1e-9)
        #expect(series.stats.current == series.points.last?.1)
        #expect(series.stats.minimum! <= series.stats.average! && series.stats.average! <= series.stats.maximum!)
        #expect(!series.monthly.isEmpty)
        #expect(series.lastYear.isEmpty)
        #expect(series.reading.contains("subiu"))
        if kind == .hrv {
            #expect(series.normalBand == 55...68)
        } else {
            #expect(series.normalBand == nil)
            #expect(series.points.last!.1 < 60)
        }
    }

    @Test func movingAverageUsesLastSevenDays() throws {
        let values: [Double] = [10, 20, 30, 40, 50, 60, 70, 80]
        let models: [any PersistentModel] = values.enumerated().map { index, value in
            daily(daysAgo: values.count - 1 - index, restingHR: Int(value))
        }
        let context = try makeContext(models)

        let series = try metricSeries(.restingHeartRate, context: context, today: fixtureToday, period: .sixMonths)

        #expect(series.movingAverage7.first?.1 == 10)
        #expect(series.movingAverage7.last?.1 == 50)
        #expect(series.projection.isEmpty)
    }

    @Test func lastYearShiftsWindowAndMonthlyAverages() throws {
        let models: [any PersistentModel] = [
            daily(daysAgo: 0, sleepScore: 80),
            daily(daysAgo: 1, sleepScore: 70),
            daily(daysAgo: 365, sleepScore: 60),
            daily(daysAgo: 600, sleepScore: 10),
        ]
        let context = try makeContext(models)

        let series = try metricSeries(.sleep, context: context, today: fixtureToday, period: .sixMonths)

        #expect(series.points.map(\.1) == [70, 80])
        #expect(series.lastYear.count == 1)
        #expect(series.lastYear.first?.0 == fixtureToday)
        #expect(series.lastYear.first?.1 == 60)
        #expect(series.monthly.count == 1)
        #expect(series.monthly.first?.0 == Day(year: 2026, month: 11, day: 1))
        #expect(series.monthly.first?.1 == 75)
    }

    @Test func predictionKindUsesEfforts() throws {
        let context = try makeContext(improvingRuns())

        let series = try metricSeries(.prediction5k, context: context, today: fixtureToday, period: .sixMonths)

        #expect(series.points.last?.1 == 1_500)
        #expect(series.reading.contains("caiu"))
    }
}
