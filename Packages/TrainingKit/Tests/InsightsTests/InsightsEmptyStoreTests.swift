import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Insights

@Suite struct InsightsEmptyStoreTests {
    @Test func everyBuilderWorksOnEmptyStore() throws {
        let context = try makeContext()

        let summary = try todaySummary(context: context, today: fixtureToday)
        #expect(summary.readiness == nil)
        #expect(summary.verdict == nil)
        #expect(summary.race.today == nil)
        #expect(summary.race.goalCrossing == .noGoal)
        #expect(summary.raceCountdownDays == nil && summary.racePriority == nil)
        #expect(summary.week.total == 0 && summary.week.lastWeek == 0 && summary.week.average4Weeks == 0)
        #expect(summary.predictions.allSatisfy { $0.seconds == nil })
        #expect(summary.lastRunId == nil)
        #expect(summary.supporting.acuteChronic == nil && summary.supporting.hrvVsBaseline == nil)

        let state = try overallState(context: context, today: fixtureToday)
        #expect(state.facts.total == 0)
        #expect(state.facts.verdict == .stable)
        #expect(state.indicators.allSatisfy { $0.trend == .unknown })

        #expect(try targetRace(in: context, today: fixtureToday) == nil)

        for kind in MetricKind.allCases {
            for period in MetricPeriod.allCases {
                let series = try metricSeries(kind, context: context, today: fixtureToday, period: period)
                #expect(series.points.isEmpty)
                #expect(series.projection.isEmpty && series.raceDayValue == nil)
                #expect(series.reading == "Sem dados suficientes para esta métrica.")
            }
        }
    }
}
