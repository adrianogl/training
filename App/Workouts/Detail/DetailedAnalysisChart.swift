import Charts
import Insights
import SwiftUI
import WorkoutAnalysis

struct DetailedKilometerChart: View {
    let analysis: DetailedAnalysis

    private typealias C = DetailedScreenConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSCardLabel(C.kmTitle)
            paceChart
            if analysis.splits.contains(where: { $0.heartRate != nil }) {
                heartRateChart
            }
            HStack(spacing: 12) {
                legend(C.paceLegend, color: BrandColors.fitness)
                legend(C.heartRateLegend, color: BrandColors.race)
            }
        }
        .brandCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(C.chartAccessibility)
    }

    private var paceChart: some View {
        let paces = analysis.splits.map(\.paceSeconds)
        let low = (paces.min() ?? 0) - 6
        let high = (paces.max() ?? 0) + 6
        return Chart {
            ForEach(analysis.splits) { split in
                LineMark(x: .value("km", split.km), y: .value("pace", -split.paceSeconds))
                    .foregroundStyle(BrandColors.fitness)
                    .lineStyle(StrokeStyle(lineWidth: C.lineWidth))
                PointMark(x: .value("km", split.km), y: .value("pace", -split.paceSeconds))
                    .symbolSize(24)
                    .foregroundStyle(BrandColors.fitness)
            }
            marks
        }
        .chartYScale(domain: -high...(-low))
        .chartXScale(domain: 1...max(analysis.splits.count, 2))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) { AxisValueLabel() } }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(BrandColors.line)
                AxisValueLabel {
                    if let pace = value.as(Double.self) { Text(WorkoutFormat.clock(-pace)).font(.caption2) }
                }
            }
        }
        .chartPlotStyle { $0.clipped() }
        .frame(height: C.chartHeight)
    }

    private var heartRateChart: some View {
        let rates = analysis.splits.compactMap(\.heartRate)
        let low = (rates.min() ?? 0) - 4
        let high = (rates.max() ?? 0) + 4
        return Chart {
            ForEach(analysis.splits) { split in
                if let heartRate = split.heartRate {
                    LineMark(x: .value("km", split.km), y: .value("FC", heartRate))
                        .foregroundStyle(BrandColors.race)
                        .lineStyle(StrokeStyle(lineWidth: C.lineWidth))
                }
            }
            marks
        }
        .chartYScale(domain: low...high)
        .chartXScale(domain: 1...max(analysis.splits.count, 2))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(BrandColors.line)
                AxisValueLabel().font(.caption2)
            }
        }
        .chartPlotStyle { $0.clipped() }
        .frame(height: C.heartRateChartHeight)
    }

    @ChartContentBuilder
    private var marks: some ChartContent {
        if let fade = analysis.fadeKm {
            RuleMark(x: .value("km", fade))
                .foregroundStyle(BrandColors.attention.opacity(C.ruleOpacity))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: C.ruleDash))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    Text(String(format: C.fadeLabelFormat, fade)).font(.caption2).foregroundStyle(BrandColors.attention)
                }
        }
        ForEach(Array(visiblePauses.enumerated()), id: \.offset) { _, km in
            RuleMark(x: .value("km", km))
                .foregroundStyle(BrandColors.rest.opacity(C.ruleOpacity))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: C.ruleDash))
        }
    }

    private var visiblePauses: [Double] {
        let last = Double(max(analysis.splits.count, 2))
        return analysis.pauseKilometers.filter { $0 >= 1 && $0 <= last }
    }

    private func legend(_ text: String, color: Color) -> some View {
        DSLegendItem(text: text, color: color)
    }
}

struct DetailedSimilarChart: View {
    let bars: [SimilarBar]

    private typealias C = DetailedScreenConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSCardLabel(C.similarTitle)
            Chart(bars) { bar in
                BarMark(x: .value("treino", bar.label), y: .value("%", bar.percent))
                    .foregroundStyle(color(bar.role))
                    .cornerRadius(C.barCornerRadius)
                    .annotation(position: .top, spacing: 2) {
                        Text("\(Int(bar.percent.rounded()))%").font(.caption2).foregroundStyle(BrandColors.dim)
                    }
            }
            .chartXScale(domain: bars.map(\.label))
            .chartYScale(domain: 0...max(110, (bars.map(\.percent).max() ?? 100) + 10))
            .chartYAxis(.hidden)
            .frame(height: C.similarChartHeight)
            HStack(spacing: 12) {
                legend(C.legendClean, color: BrandColors.accentFill)
                legend(C.legendComplete, color: BrandColors.fitness)
                legend(C.legendPartial, color: BrandColors.fitness.opacity(C.partialOpacity))
                legend(C.legendToday, color: BrandColors.attention)
            }
        }
        .brandCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(C.similarAccessibility)
    }

    private func color(_ role: SimilarBarRole) -> Color {
        switch role {
        case .clean: BrandColors.accentFill
        case .complete: BrandColors.fitness
        case .partial: BrandColors.fitness.opacity(C.partialOpacity)
        case .today: BrandColors.attention
        }
    }

    private func legend(_ text: String, color: Color) -> some View {
        DSLegendItem(text: text, color: color)
    }
}
