import Charts
import Insights
import SwiftUI
import TrainingCore

struct VolumeHistoryCard: View {
    let week: WeekVolume
    var goal = 0
    var planned: [Day: Double] = [:]

    private typealias C = TodayConstants

    var body: some View {
        let series = VolumeSeriesBuilder.make(week: week, planned: planned)
        VStack(alignment: .leading, spacing: 10) {
            if !planned.isEmpty { legend }
            chart(series)
                .frame(height: C.volumeChartHeight)
                .accessibilityLabel(accessibility(series))
            footer(series)
        }
        .brandCard(fillsHeight: true)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            legendItem(C.volumeLegendDone, BrandColors.accentFill, dashed: false)
            legendItem(C.volumeLegendPlanned, BrandColors.dim, dashed: true)
            legendItem(C.volumeLegendBelow, BrandColors.attention, dashed: false)
        }
    }

    private func legendItem(_ text: String, _ color: Color, dashed: Bool) -> some View {
        DSLegendItem(text: text, color: color, mark: dashed ? .dashed : .line)
    }

    private func chart(_ series: VolumeSeries) -> some View {
        let points = series.points
        let top = max(points.map { max($0.kilometers, $0.plannedKm ?? 0) }.max() ?? 0, series.projectedKm ?? 0, Double(goal)) * C.volumeHeadroom
        return Chart {
            ForEach(Array(zip(points, points.dropFirst()).enumerated()), id: \.offset) { index, pair in
                if let low = pair.0.plannedKm, let high = pair.1.plannedKm, pair.0.kilometers < low || pair.1.kilometers < high {
                    AreaMark(x: .value("Semana", label(pair.0.start)), yStart: .value("km", pair.0.kilometers), yEnd: .value("Planejado", max(pair.0.kilometers, low)), series: .value("Faixa", "gap\(index)"))
                        .foregroundStyle(BrandColors.attention.opacity(C.volumeGapOpacity))
                    AreaMark(x: .value("Semana", label(pair.1.start)), yStart: .value("km", pair.1.kilometers), yEnd: .value("Planejado", max(pair.1.kilometers, high)), series: .value("Faixa", "gap\(index)"))
                        .foregroundStyle(BrandColors.attention.opacity(C.volumeGapOpacity))
                }
            }
            ForEach(Array(plannedRuns(points).enumerated()), id: \.offset) { index, run in
                ForEach(run) { point in
                    LineMark(x: .value("Semana", label(point.start)), y: .value("Planejado", point.plannedKm ?? 0), series: .value("Plano", "plan\(index)"))
                        .foregroundStyle(BrandColors.dim)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    PointMark(x: .value("Semana", label(point.start)), y: .value("Planejado", point.plannedKm ?? 0))
                        .foregroundStyle(BrandColors.dim)
                        .symbolSize(C.volumePlannedPointSize)
                }
            }
            ForEach(points) { point in
                LineMark(x: .value("Semana", label(point.start)), y: .value("km", point.kilometers), series: .value("Linha", "done"))
                    .foregroundStyle(BrandColors.accentFill)
                    .lineStyle(StrokeStyle(lineWidth: C.volumeLineWidth, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Semana", label(point.start)), y: .value("km", point.kilometers))
                    .foregroundStyle(pointColor(point))
                    .symbolSize(C.volumePointSize)
                    .annotation(position: .top, spacing: C.volumeAxisLabelSpacing) {
                        Text(TodayText.decimal(point.kilometers, fractionDigits: 0)).font(.caption2.weight(.semibold)).foregroundStyle(BrandColors.text)
                    }
            }
            if let current = series.current, let projected = series.projectedKm {
                LineMark(x: .value("Semana", label(current.start)), y: .value("km", current.kilometers), series: .value("Linha", "projection"))
                    .foregroundStyle(BrandColors.accentFill)
                    .lineStyle(StrokeStyle(lineWidth: C.volumeLineWidth, dash: [3, 3]))
                LineMark(x: .value("Semana", label(current.start)), y: .value("km", projected), series: .value("Linha", "projection"))
                    .foregroundStyle(BrandColors.accentFill)
                    .lineStyle(StrokeStyle(lineWidth: C.volumeLineWidth, dash: [3, 3]))
                PointMark(x: .value("Semana", label(current.start)), y: .value("km", projected))
                    .foregroundStyle(BrandColors.accentFill.opacity(C.volumeProjectionOpacity))
                    .symbolSize(C.volumePointSize)
            }
            if goal > 0 {
                RuleMark(y: .value(C.volumeGoalLabel, Double(goal)))
                    .foregroundStyle(BrandColors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("\(C.volumeGoalLabel) \(goal) km").font(.caption2.weight(.bold)).foregroundStyle(BrandColors.accent)
                    }
            }
            if series.average4Weeks > 0 && planned.isEmpty {
                RuleMark(y: .value(C.volumeAverageLabel, series.average4Weeks))
                    .foregroundStyle(BrandColors.marker)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXScale(domain: points.map { label($0.start) })
        .chartYScale(domain: 0...max(top, 1))
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(BrandColors.line)
                AxisValueLabel().foregroundStyle(BrandColors.dim)
            }
        }
        .chartXAxis {
            AxisMarks(values: points.map { label($0.start) }) { value in
                AxisValueLabel(centered: false) {
                    if let text = value.as(String.self), let point = points.first(where: { label($0.start) == text }) {
                        VStack(spacing: 2) {
                            Text(text).foregroundStyle(BrandColors.dim)
                            if let percent = point.percent {
                                Text(String(format: C.adherenceFormat, percent))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(percentColor(point))
                            }
                        }
                    }
                }
            }
        }
    }

    private func footer(_ series: VolumeSeries) -> some View {
        HStack(alignment: .top, spacing: 8) {
            block(
                String(format: C.volumeKmFormat, TodayText.decimal(week.total, fractionDigits: 1)),
                series.projectedKm.map { String(format: C.volumeClosesFormat, TodayText.decimal($0, fractionDigits: 0)) } ?? C.volumeThisWeek
            )
            block(String(format: C.volumeKmFormat, TodayText.decimal(series.average4Weeks, fractionDigits: 1)), C.volumeAverageCaption)
            if let percent = series.adherencePercent {
                block(String(format: C.adherenceFormat, percent), C.volumeAdherenceCaption)
            }
        }
    }

    private func block(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(BrandFonts.number(18)).foregroundStyle(BrandColors.text)
            Text(caption).font(.caption2).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption): \(value)")
    }

    private func plannedRuns(_ points: [VolumePoint]) -> [[VolumePoint]] {
        var runs: [[VolumePoint]] = []
        var run: [VolumePoint] = []
        for point in points {
            if point.plannedKm != nil {
                run.append(point)
            } else if !run.isEmpty {
                runs.append(run)
                run = []
            }
        }
        if !run.isEmpty { runs.append(run) }
        return runs
    }

    private func pointColor(_ point: VolumePoint) -> Color {
        guard let ratio = point.ratio else { return BrandColors.accentFill }
        return ratio >= C.volumePercentGood ? BrandColors.accentFill : BrandColors.attention
    }

    private func percentColor(_ point: VolumePoint) -> Color {
        (point.ratio ?? 0) >= C.volumePercentGood ? BrandColors.accent : BrandColors.attention
    }

    private func accessibility(_ series: VolumeSeries) -> String {
        series.points.map { point in
            let done = TodayText.decimal(point.kilometers, fractionDigits: 1)
            guard let plan = point.plannedKm, let percent = point.percent else { return "\(label(point.start)): \(done) km" }
            return String(format: C.volumeAccessibilityFormat, label(point.start), done, TodayText.decimal(plan, fractionDigits: 1), percent)
        }.joined(separator: "; ")
    }

    private func label(_ day: Day) -> String {
        let formatter = DateFormatter()
        formatter.locale = WorkoutConstants.locale
        formatter.dateFormat = C.volumeWeekFormat
        return formatter.string(from: day.chartDate).replacingOccurrences(of: ".", with: "")
    }
}
