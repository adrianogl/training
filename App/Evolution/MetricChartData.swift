import Foundation
import Insights
import TrainingCore

struct MetricChartMarker: Sendable, Identifiable {
    let date: Date
    let name: String

    var id: Date { date }
}

struct MetricChartData: Sendable {
    var kind: MetricKind
    var daily: [ChartPoint]
    var average: [ChartPoint]
    var lastYear: [ChartPoint]
    var projection: [ChartPoint]
    var projectionBand: [ChartBandPoint]
    var normalBand: ClosedRange<Double>?
    var markers: [MetricChartMarker]
    var raceDayPoint: ChartPoint?
    var todayDate: Date

    var isEmpty: Bool { average.isEmpty && daily.isEmpty }

    var xRange: ClosedRange<Date>? {
        let dates = (daily + average + projection).map(\.date)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        return first...last
    }

    func clippingProjection(after limit: Date?) -> MetricChartData {
        guard let limit else { return self }
        var copy = self
        copy.projection = projection.filter { $0.date <= limit }
        copy.projectionBand = projectionBand.filter { $0.date <= limit }
        return copy
    }

    static func make(series: MetricSeries, markers: [RaceMarker], raceDay: Day?, today: Day, compact: Bool) -> MetricChartData {
        let average = series.movingAverage7.map { ChartPoint(date: $0.0.chartDate, value: $0.1) }
        let projection = series.projection.map { ChartPoint(date: $0.day.chartDate, value: $0.mid) }
        let anchored = average.last.map { [$0] + projection } ?? projection
        let first = average.first?.date ?? today.chartDate
        let last = (projection.last?.date ?? today.chartDate)
        let visibleMarkers = compact ? [] : markers
            .map { MetricChartMarker(date: $0.day.chartDate, name: $0.name) }
            .filter { $0.date >= first && $0.date <= last }
        var raceDayPoint: ChartPoint?
        if let value = series.raceDayValue, let raceDay { raceDayPoint = ChartPoint(date: raceDay.chartDate, value: value) }
        return MetricChartData(
            kind: series.kind,
            daily: compact ? [] : series.points.map { ChartPoint(date: $0.0.chartDate, value: $0.1) },
            average: compact ? downsample(average, limit: EvolutionConstants.compactPointLimit) : average,
            lastYear: compact ? [] : series.lastYear.map { ChartPoint(date: $0.0.chartDate, value: $0.1) },
            projection: anchored,
            projectionBand: series.projection.map { ChartBandPoint(date: $0.day.chartDate, low: $0.low, high: $0.high) },
            normalBand: series.normalBand,
            markers: visibleMarkers,
            raceDayPoint: raceDayPoint,
            todayDate: today.chartDate
        )
    }

    private static func downsample(_ points: [ChartPoint], limit: Int) -> [ChartPoint] {
        guard points.count > limit, limit > 1 else { return points }
        let step = Double(points.count - 1) / Double(limit - 1)
        return (0..<limit).map { points[Int((Double($0) * step).rounded())] }
    }
}
