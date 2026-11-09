import Foundation
import Insights
import Observation
import Storage
import SwiftData
import TrainingCore

@MainActor @Observable final class MetricDetailModel {
    typealias C = EvolutionConstants

    let kind: MetricKind
    let today: Day
    @ObservationIgnored private let container: ModelContainer
    private(set) var period: MetricPeriod
    private(set) var series: MetricSeries?
    private(set) var chart: MetricChartData?
    private(set) var monthly: [MonthlyMean] = []
    private(set) var isLoading = false

    init(kind: MetricKind, period: MetricPeriod, container: ModelContainer, today: Day) {
        self.kind = kind
        self.period = period
        self.container = container
        self.today = today
    }

    func load() async {
        await load(period: period)
    }

    func select(period newPeriod: MetricPeriod) async {
        guard newPeriod != period else { return }
        period = newPeriod
        await load(period: newPeriod)
    }

    var name: String { C.metricNames[kind] ?? "" }

    var stats: MetricStats? { series?.stats }

    var statCells: [MetricStatCell] {
        series.map { EvolutionText.statCells(kind: kind, stats: $0.stats) } ?? []
    }

    var change: (text: String, trend: IndicatorTrend)? {
        series.flatMap { EvolutionText.change(kind: kind, stats: $0.stats) }
    }

    var raceDayText: String? {
        series?.raceDayValue.map { EvolutionText.value($0, C.metricFormats[kind]) }
    }

    var reading: String? {
        guard let series, !series.points.isEmpty else { return nil }
        return series.reading
    }

    var lastYearText: String? {
        guard let series, let chart else { return nil }
        return EvolutionText.lastYearLine(kind: kind, stats: series.stats, lastYear: chart.lastYear)
    }

    var hasData: Bool { chart.map { !$0.isEmpty } ?? false }

    private func load(period requested: MetricPeriod) async {
        isLoading = true
        let container = container
        let today = today
        let kind = kind
        let result = await Task.detached(priority: .userInitiated) {
            Self.compute(container: container, today: today, kind: kind, period: requested)
        }.value
        guard !Task.isCancelled, requested == period else { return }
        series = result?.series
        chart = result?.chart
        monthly = result?.monthly ?? []
        isLoading = false
    }

    nonisolated private static func compute(
        container: ModelContainer, today: Day, kind: MetricKind, period: MetricPeriod
    ) -> MetricDetailLoad? {
        let context = ModelContext(container)
        guard let series = try? metricSeries(kind, context: context, today: today, period: period) else { return nil }
        let target = (try? targetRace(in: context, today: today)) ?? nil
        let chart = MetricChartData.make(
            series: series,
            markers: EvolutionModel.raceMarkers(context: context),
            raceDay: target.flatMap { Day(iso: $0.day) },
            today: today,
            compact: false
        )
        let monthly = series.monthly.suffix(EvolutionConstants.monthlyBars).map { MonthlyMean(date: $0.0.chartDate, value: $0.1) }
        return MetricDetailLoad(series: series, chart: chart, monthly: Array(monthly))
    }
}
