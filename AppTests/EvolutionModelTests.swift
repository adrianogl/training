import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct EvolutionModelTests {
    private static let today = Day(iso: WorkoutDetailFixtures.day(WorkoutDetailFixtures.base))!

    private static func store(goalSeconds: Double? = 6_300) throws -> ModelContainer {
        let container = try TodayModelTests.store(withRace: true, goalSeconds: goalSeconds)
        let context = container.mainContext
        for offset in 41...300 {
            context.insert(DailyRecord(day: today.adding(days: -offset).iso, restingHR: 50 + offset % 5, hrvLastNight: 60))
        }
        try context.save()
        return container
    }

    @Test func evolutionShowsSixIndicatorsInOrder() async throws {
        let model = EvolutionModel(container: try Self.store(), today: Self.today)
        #expect(model.isLoaded == false)
        await model.load()

        #expect(model.isLoaded)
        #expect(model.overall.indicators.map(\.kind) == [.racePrediction, .vo2max, .fitness, .zone2Pace, .thresholdPace, .monthlyVolume])
        #expect(model.indicators.count == 6)
        #expect(model.indicators.first?.name == "Previsão 21,1 km")
        #expect(!model.overallSentence.isEmpty)
        #expect(model.cards.first == .vo2max)
        #expect(Set(model.cards).isSuperset(of: [.hrv, .sleep, .restingHeartRate, .bodyBattery, .zoneDistribution]))
        #expect(model.cardData[.restingHeartRate] != nil)
        #expect(model.indicators.filter(\.windowed).map(\.kind) == [.zone2Pace, .thresholdPace])
    }

    @Test func goalGapOnlyOnPrediction() async throws {
        let model = EvolutionModel(container: try Self.store(), today: Self.today)
        await model.load()

        let withGoal = model.overall.indicators.filter { $0.goalGap != nil }.map(\.kind)
        #expect(withGoal == [.racePrediction])
        #expect(model.indicators.filter { $0.goalText != nil }.map(\.kind) == [.racePrediction])
        let prediction = try #require(model.indicators.first { $0.kind == .racePrediction })
        let source = try #require(model.overall.indicators.first { $0.kind == .racePrediction })
        #expect(prediction.lowerIsBetter)
        #expect(prediction.goal == source.today.flatMap { today in source.goalGap.map { today - $0 } })
        #expect(prediction.then == source.today.flatMap { today in source.delta.map { today - $0 } })
        #expect(model.indicators.filter(\.lowerIsBetter).map(\.kind) == [.racePrediction, .zone2Pace, .thresholdPace])
    }

    @Test func evolutionPeriodReloadsCards() async throws {
        let model = EvolutionModel(container: try Self.store(), today: Self.today)
        await model.load()
        let oneYearStart = model.cardData[.restingHeartRate]?.chart.average.first?.date
        await model.select(period: .sixMonths)
        let sixMonthsStart = model.cardData[.restingHeartRate]?.chart.average.first?.date

        #expect(model.period == .sixMonths)
        #expect(model.isLoadingCards == false)
        #expect(oneYearStart != nil && sixMonthsStart != nil)
        #expect((oneYearStart ?? .distantFuture) < (sixMonthsStart ?? .distantPast))
    }

    @Test func metricDetailSwitchesPeriod() async throws {
        let model = MetricDetailModel(kind: .restingHeartRate, period: .sixMonths, container: try Self.store(), today: Self.today)
        await model.load()
        let sixMonths = model.series?.points.count ?? 0
        #expect(sixMonths > 0)
        #expect(model.statCells.count == 4)

        await model.select(period: .oneYear)

        #expect(model.period == .oneYear)
        #expect((model.series?.points.count ?? 0) > sixMonths)
        #expect(model.chart?.daily.count == model.series?.points.count)
        #expect(model.isLoading == false)
    }

    @Test func emptyStoreStillLoads() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let model = EvolutionModel(container: container, today: Self.today)
        await model.load()
        #expect(model.isLoaded)
        #expect(model.indicators.allSatisfy { $0.todayText == "—" })
    }

    @Test func highlightFollowsHorizon() async throws {
        let model = EvolutionModel(container: try Self.store(), today: Self.today)
        await model.load()
        func projectedCount() -> Int { model.highlight.lines.last(where: { $0.dashed })?.points.count ?? 0 }

        let untilRace = projectedCount()
        model.horizon = .sixMonths
        let sixMonths = projectedCount()
        model.horizon = .oneYear
        let oneYear = projectedCount()

        #expect(untilRace == 35)
        #expect(sixMonths == 183)
        #expect(oneYear == 366)
    }

    @Test func heatmapCoversTwentySixWeeks() async throws {
        let model = EvolutionModel(container: try Self.store(), today: Self.today)
        await model.load()

        let columns = model.heatmapColumns
        #expect(columns.count == 26)
        #expect(columns.allSatisfy { $0.count == 7 })
        #expect(columns.flatMap { $0 }.contains { $0.kilometers > 0 })
    }
}
