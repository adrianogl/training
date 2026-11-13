import Foundation
import Insights
import Narrative

enum EvolutionText {
    typealias C = EvolutionConstants

    static func value(_ value: Double?, _ format: MetricValueFormat?) -> String {
        guard let value, let format else { return C.emptyValue }
        switch format {
        case .pace, .duration:
            return WorkoutListModel.clockText(value)
        case .number(let decimals, let unit):
            return TodayText.decimal(value, fractionDigits: decimals) + unit
        }
    }

    static func delta(_ value: Double?, _ format: MetricValueFormat?) -> String? {
        guard let value, let format else { return nil }
        switch format {
        case .pace, .duration:
            let seconds = Int(abs(value).rounded())
            let sign = seconds == 0 ? "" : (value > 0 ? "+" : C.minusSign)
            return sign + WorkoutListModel.clockText(Double(seconds))
        case .number(let decimals, let unit):
            return TodayText.signed(value, fractionDigits: decimals) + unit
        }
    }

    static func verdictTitle(_ verdict: OverallVerdict) -> String {
        switch verdict {
        case .better: C.verdictBetter
        case .stable: C.verdictStable
        case .worse: C.verdictWorse
        }
    }

    static func dumbbells(overall: OverallState, outlook: RaceOutlook) -> [IndicatorDumbbellData] {
        overall.indicators.map { indicator in
            let format = C.indicatorFormats[indicator.kind]
            let isPrediction = indicator.kind == .racePrediction
            let then = indicator.today.flatMap { today in indicator.delta.map { today - $0 } }
            let goal = isPrediction ? indicator.today.flatMap { today in indicator.goalGap.map { today - $0 } } : nil
            return IndicatorDumbbellData(
                kind: indicator.kind,
                name: name(indicator.kind, outlook: outlook),
                then: then,
                today: indicator.today,
                goal: goal,
                lowerIsBetter: C.lowerIsBetterIndicators.contains(indicator.kind),
                todayText: value(indicator.today, format),
                windowed: C.windowedIndicators.contains(indicator.kind),
                deltaText: delta(indicator.delta, format),
                trend: indicator.trend,
                goalText: isPrediction ? delta(indicator.goalGap, format) : nil,
                goalPending: (indicator.goalGap ?? 0) > 0
            )
        }
    }

    static func name(_ kind: IndicatorKind, outlook: RaceOutlook) -> String {
        switch kind {
        case .racePrediction: outlook.label.isEmpty ? C.predictionPrefix : "\(C.predictionPrefix) \(outlook.label)"
        case .vo2max: C.metricNames[.vo2max] ?? ""
        case .fitness: C.metricNames[.fitness] ?? ""
        case .zone2Pace: C.metricNames[.zone2Pace] ?? ""
        case .thresholdPace: C.metricNames[.thresholdPace] ?? ""
        case .monthlyVolume: C.metricNames[.monthlyVolume] ?? ""
        }
    }

    static func change(kind: MetricKind, stats: MetricStats) -> (text: String, trend: IndicatorTrend)? {
        guard let change = stats.change, let text = delta(change, C.metricFormats[kind]) else { return nil }
        guard abs(change) > 0 else { return (text, .same) }
        if C.lowerIsBetter.contains(kind) { return (text, change < 0 ? .better : .worse) }
        if C.higherIsBetter.contains(kind) { return (text, change > 0 ? .better : .worse) }
        return (text, .unknown)
    }

    static func statCells(kind: MetricKind, stats: MetricStats) -> [MetricStatCell] {
        let format = C.metricFormats[kind]
        return [
            MetricStatCell(title: C.detailCurrent, value: value(stats.current, format)),
            MetricStatCell(title: C.detailAverage, value: value(stats.average, format)),
            MetricStatCell(title: C.detailMinimum, value: value(stats.minimum, format)),
            MetricStatCell(title: C.detailMaximum, value: value(stats.maximum, format)),
        ]
    }

    static func lastYearLine(kind: MetricKind, stats: MetricStats, lastYear: [ChartPoint]) -> String? {
        guard !lastYear.isEmpty, let average = stats.average else { return nil }
        let previous = lastYear.map(\.value).reduce(0, +) / Double(lastYear.count)
        let format = C.metricFormats[kind]
        guard let diff = delta(average - previous, format) else { return nil }
        return String(format: C.detailLastYearFormat, value(previous, format), diff)
    }
}
