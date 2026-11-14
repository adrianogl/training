import Foundation
import Insights
import Narrative
import TrainingCore

enum MetricValueFormat: Sendable {
    case pace
    case duration
    case number(decimals: Int, unit: String)
}

enum ProjectionHorizon: String, CaseIterable, Identifiable, Sendable {
    case untilRace, sixMonths, oneYear

    var id: String { rawValue }
}

struct RaceContext: Sendable, Equatable {
    var countdownDays: Int?
    var priority: String?
}

struct RaceMarker: Sendable, Equatable {
    let day: Day
    let name: String
}

struct EvolutionOverview: Sendable {
    let overall: OverallState
    let heatmap: [Day: Double]
    let outlook: RaceOutlook
    let race: RaceContext
    let markers: [RaceMarker]
    let zoneWeeks: [ZoneWeek]
    let records: [PersonalRecord]
}

struct MetricCardData: Sendable, Identifiable {
    let kind: MetricKind
    let stats: MetricStats
    let chart: MetricChartData
    var monthly: [MonthlyMean] = []

    var id: MetricKind { kind }
}

struct MetricGroup: Identifiable, Sendable {
    let title: String
    let kinds: [MetricKind]

    var id: String { title }
}

struct IndicatorDumbbellData: Identifiable, Equatable {
    let kind: IndicatorKind
    let name: String
    let then: Double?
    let today: Double?
    let goal: Double?
    let lowerIsBetter: Bool
    let todayText: String
    let windowed: Bool
    let deltaText: String?
    let trend: IndicatorTrend
    let goalText: String?
    let goalPending: Bool

    var id: IndicatorKind { kind }
}

struct MetricStatCell: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String { title }
}

struct MonthlyMean: Identifiable, Sendable {
    let date: Date
    let value: Double

    var id: Date { date }
}

extension OverallFacts {
    static var empty: OverallFacts {
        OverallFacts(verdict: .stable, improved: 0, worsened: 0, total: 0, goalGapSeconds: nil, raceDayGapSeconds: nil)
    }
}

struct MetricDetailLoad: Sendable {
    let series: MetricSeries
    let chart: MetricChartData
    let monthly: [MonthlyMean]
}

struct MetricPeriodOption {
    let period: MetricPeriod
    let title: String

    static let all = MetricPeriod.allCases.map { MetricPeriodOption(period: $0, title: EvolutionConstants.periodTitles[$0] ?? "") }
}

struct HorizonOption {
    let horizon: ProjectionHorizon
    let title: String

    static let all = ProjectionHorizon.allCases.map { HorizonOption(horizon: $0, title: EvolutionConstants.horizonTitles[$0] ?? "") }
}

enum MetricChartStyle {
    case compact
    case full
}

struct HeatmapCell: Identifiable, Equatable {
    let day: Day
    let kilometers: Double
    let level: Double
    let isFuture: Bool

    var id: Day { day }
}
