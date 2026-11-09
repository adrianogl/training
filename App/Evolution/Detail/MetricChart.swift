import Charts
import SwiftUI

enum MetricChartStyle {
    case compact
    case full
}

struct MetricChart: View {
    let data: MetricChartData
    let style: MetricChartStyle

    private var reversed: Bool { EvolutionConstants.reversedAxis.contains(data.kind) }
    private var isFull: Bool { style == .full }

    var body: some View {
        Chart {
            if isFull, let band = data.normalBand, let range = data.xRange {
                RectangleMark(
                    xStart: .value("Início", range.lowerBound), xEnd: .value("Fim", range.upperBound),
                    yStart: .value("Mínimo", band.lowerBound), yEnd: .value("Máximo", band.upperBound)
                )
                .foregroundStyle(BrandColors.band.opacity(0.14))
            }
            ForEach(Array(data.projectionBand.enumerated()), id: \.offset) { _, point in
                AreaMark(x: .value("Dia", point.date), yStart: .value("Mínimo", point.low), yEnd: .value("Máximo", point.high))
                    .foregroundStyle(BrandColors.accent.opacity(0.14))
            }
            ForEach(Array(data.lastYear.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("Dia", point.date), y: .value("Valor", point.value), series: .value("Série", EvolutionConstants.lastYearLabel))
                    .foregroundStyle(BrandColors.dim.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
            ForEach(Array(data.daily.enumerated()), id: \.offset) { _, point in
                PointMark(x: .value("Dia", point.date), y: .value("Valor", point.value))
                    .foregroundStyle(BrandColors.fitness.opacity(0.45))
                    .symbolSize(10)
            }
            ForEach(Array(data.average.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("Dia", point.date), y: .value("Valor", point.value), series: .value("Série", EvolutionConstants.averageLabel))
                    .foregroundStyle(BrandColors.text)
                    .lineStyle(StrokeStyle(lineWidth: isFull ? 2 : 1.5))
            }
            ForEach(Array(data.projection.enumerated()), id: \.offset) { _, point in
                LineMark(x: .value("Dia", point.date), y: .value("Valor", point.value), series: .value("Série", EvolutionConstants.projectionLabel))
                    .foregroundStyle(BrandColors.accent)
                    .lineStyle(StrokeStyle(lineWidth: isFull ? 2 : 1.5, dash: [5, 4]))
            }
            if isFull {
                RuleMark(x: .value("Hoje", data.todayDate)).foregroundStyle(BrandColors.marker)
                ForEach(data.markers) { marker in
                    RuleMark(x: .value("Prova", marker.date))
                        .foregroundStyle(BrandColors.race.opacity(0.6))
                        .annotation(position: .top, alignment: .leading) {
                            Text(marker.name).font(.caption2).foregroundStyle(BrandColors.race).lineLimit(1)
                        }
                }
                if let point = data.raceDayPoint {
                    PointMark(x: .value("Prova", point.date), y: .value("Projetado", point.value))
                        .foregroundStyle(BrandColors.accent)
                        .symbolSize(70)
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false, reversed: reversed))
        .chartXAxis(isFull ? .automatic : .hidden)
        .chartXAxis {
            if isFull {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(BrandColors.line)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits).locale(WorkoutConstants.locale))
                }
            }
        }
        .chartYAxis {
            if isFull {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(BrandColors.line)
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(EvolutionText.value(number, EvolutionConstants.metricFormats[data.kind]))
                        }
                    }
                }
            }
        }
        .frame(height: isFull ? EvolutionConstants.detailChartHeight : EvolutionConstants.cardChartHeight)
    }
}
