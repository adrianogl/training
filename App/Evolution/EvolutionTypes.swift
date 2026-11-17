import Foundation
import Insights
import Narrative
import TrainingCore

enum MetricValueFormat: Sendable {
    case pace
    case duration
    case number(decimals: Int, unit: String)
}

struct RaceContext: Sendable, Equatable, Codable {
    var countdownDays: Int?
    var priority: String?
}

struct RaceMarker: Sendable, Equatable, Codable {
    let day: Day
    let name: String
}

struct EvolutionOverview: Sendable, Codable {
    let overall: OverallState
    let heatmap: [Day: Double]
    let outlook: RaceOutlook
    let race: RaceContext
    let markers: [RaceMarker]
    let zoneWeeks: [ZoneWeek]
    let records: [PersonalRecord]
}

struct MetricCardData: Sendable, Identifiable, Codable {
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
    var featured: MetricKind? { kinds.count.isMultiple(of: 2) ? nil : kinds.first }
    var pairs: [[MetricKind]] {
        let rest = featured == nil ? kinds : Array(kinds.dropFirst())
        return stride(from: 0, to: rest.count, by: 2).map { Array(rest[$0..<min($0 + 2, rest.count)]) }
    }

    static func selected(_ title: String, in groups: [MetricGroup] = EvolutionConstants.metricGroups) -> MetricGroup? {
        groups.first { $0.title == title } ?? groups.first
    }
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

struct MonthlyMean: Identifiable, Sendable, Codable {
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

enum MetricChartStyle {
    case featured
    case full
}

struct HeatmapCell: Identifiable, Equatable {
    let day: Day
    let kilometers: Double
    let level: Double
    let isFuture: Bool

    var id: Day { day }
}
