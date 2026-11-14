import Foundation
import Insights
import Metrics
import Narrative
import Observation
import Storage
import SwiftData
import TrainingCore

@MainActor @Observable final class EvolutionModel {
    typealias C = EvolutionConstants

    let today: Day
    let cards: [MetricKind] = C.cardKinds
    @ObservationIgnored private let container: ModelContainer
    private(set) var overall = OverallState(indicators: [], facts: .empty)
    private(set) var overallSentence = ""
    private(set) var outlook = TodaySummary.empty.race
    private(set) var raceContext = RaceContext()
    private(set) var cardData: [MetricKind: MetricCardData] = [:]
    private(set) var period: MetricPeriod
    private(set) var heatmap: [Day: Double] = [:]
    private(set) var zoneWeeks: [ZoneWeek] = []
    private(set) var records: [PersonalRecord] = []
    private(set) var isLoaded = false
    private(set) var isLoadingCards = false
    var horizon = ProjectionHorizon.untilRace

    init(container: ModelContainer, today: Day, period: MetricPeriod = C.defaultPeriod, horizon: ProjectionHorizon = .untilRace) {
        self.container = container
        self.today = today
        self.period = period
        self.horizon = horizon
    }

    func load() async {
        let container = container
        let today = today
        let overview = await Task.detached(priority: .userInitiated) {
            Self.computeOverview(container: container, today: today)
        }.value
        guard !Task.isCancelled else { return }
        overall = overview.overall
        heatmap = overview.heatmap
        zoneWeeks = overview.zoneWeeks
        records = overview.records
        outlook = overview.outlook
        raceContext = overview.race
        overallSentence = TemplateInsightNarrator.overallSentence(overview.overall.facts)
        isLoaded = true
        await loadCards(for: period)
    }

    func select(period newPeriod: MetricPeriod) async {
        guard newPeriod != period else { return }
        period = newPeriod
        await loadCards(for: newPeriod)
    }

    func refreshSentence() async {
        let sentence = await makeInsightNarrator().overallSentence(overall.facts)
        guard !Task.isCancelled, !sentence.isEmpty else { return }
        overallSentence = sentence
    }

    var verdictTitle: String { EvolutionText.verdictTitle(overall.facts.verdict) }

    var indicators: [IndicatorDumbbellData] {
        EvolutionText.dumbbells(overall: overall, outlook: outlook)
    }

    var highlight: RacePredictionContent {
        RacePredictionContent(
            race: outlook,
            today: today,
            countdownDays: raceContext.countdownDays,
            priority: raceContext.priority,
            historyDays: C.periodDays[period],
            projectionDays: projectionDays
        )
    }

    var projectionDays: Int? {
        switch horizon {
        case .untilRace: raceContext.countdownDays == nil ? C.horizonCapDays : nil
        case .sixMonths, .oneYear: C.horizonDays[horizon]
        }
    }

    var heatmapColumns: [[HeatmapCell]] {
        let weeks = C.heatmapWeeks
        let first = today.weekStart.adding(days: -(weeks - 1) * 7)
        let peak = max(heatmap.values.max() ?? 0, 1)
        return (0..<weeks).map { week in
            (0..<7).map { weekday in
                let day = first.adding(days: week * 7 + weekday)
                let km = heatmap[day] ?? 0
                return HeatmapCell(day: day, kilometers: km, level: km / peak, isFuture: day > today)
            }
        }
    }

    func chart(for kind: MetricKind) -> MetricChartData? {
        cardData[kind]?.chart
    }

    private func loadCards(for requested: MetricPeriod) async {
        isLoadingCards = true
        let container = container
        let today = today
        let kinds = cards
        let data = await Task.detached(priority: .userInitiated) {
            Self.computeCards(container: container, today: today, period: requested, kinds: kinds)
        }.value
        guard !Task.isCancelled, requested == period else { return }
        cardData = data
        isLoadingCards = false
    }

    nonisolated private static func computeOverview(container: ModelContainer, today: Day) -> EvolutionOverview {
        let context = ModelContext(container)
        let overall = (try? overallState(context: context, today: today)) ?? OverallState(indicators: [], facts: .empty)
        let outlook = (try? raceOutlook(context: context, today: today)) ?? TodaySummary.empty.race
        let target = (try? targetRace(in: context, today: today)) ?? nil
        let race = RaceContext(
            countdownDays: target.flatMap { Day(iso: $0.day) }.map { today.days(until: $0) },
            priority: target?.priorityLevel.rawValue
        )
        let heatmap = (try? activityHeatmap(context: context, today: today, weeks: C.heatmapWeeks)) ?? [:]
        let runs = ((try? context.fetch(FetchDescriptor<ActivityRecord>())) ?? []).filter { ActivityTypeKey.isRun($0.typeKey) && $0.hasStart }
        return EvolutionOverview(
            overall: overall, heatmap: heatmap, outlook: outlook, race: race, markers: raceMarkers(context: context),
            zoneWeeks: EvolutionExtras.zoneWeeks(runs, today: today),
            records: EvolutionExtras.records(runs)
        )
    }

    nonisolated private static func computeCards(
        container: ModelContainer, today: Day, period: MetricPeriod, kinds: [MetricKind]
    ) -> [MetricKind: MetricCardData] {
        let context = ModelContext(container)
        let raceDay = ((try? targetRace(in: context, today: today)) ?? nil).flatMap { Day(iso: $0.day) }
        var result: [MetricKind: MetricCardData] = [:]
        for kind in kinds {
            guard !Task.isCancelled else { break }
            guard let series = try? metricSeries(kind, context: context, today: today, period: period) else { continue }
            result[kind] = MetricCardData(
                kind: kind,
                stats: series.stats,
                chart: MetricChartData.make(series: series, markers: [], raceDay: raceDay, today: today, compact: true),
                monthly: series.monthly.suffix(C.monthlyBars).map { MonthlyMean(date: $0.0.chartDate, value: $0.1) }
            )
        }
        return result
    }

    nonisolated static func raceMarkers(context: ModelContext) -> [RaceMarker] {
        let races = (try? context.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        return races.compactMap { race in Day(iso: race.day).map { RaceMarker(day: $0, name: race.name) } }
            .sorted { $0.day < $1.day }
    }
}
