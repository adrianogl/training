import Charts
import SwiftUI

struct SimilarRunsChart: View {
    let rows: [ComparisonRow]

    private typealias C = WorkoutDetailConstants

    private var points: [(index: Int, row: ComparisonRow, pace: Double)] {
        rows.reversed().compactMap { row in row.secondsPerKilometer.map { (row: row, pace: $0) } }
            .enumerated().map { (index: $0.offset, row: $0.element.row, pace: $0.element.pace) }
    }

    var body: some View {
        VStack(spacing: 4) { chart }
    }

    @ViewBuilder
    private var chart: some View {
        let points = points
        let paces = points.map(\.pace)
        let low = (paces.min() ?? 0) - C.similarChartPadding
        let high = (paces.max() ?? 0) + C.similarChartPadding
        Chart(points, id: \.index) { point in
            LineMark(x: .value("treino", point.index), y: .value("pace", -point.pace))
                .foregroundStyle(BrandColors.accentFill)
                .lineStyle(StrokeStyle(lineWidth: 2))
            PointMark(x: .value("treino", point.index), y: .value("pace", -point.pace))
                .symbolSize(point.row.isCurrent ? 110 : 55)
                .foregroundStyle(point.row.isCurrent ? BrandColors.accentFill : BrandColors.card)
                .annotation(position: .top, spacing: 4) {
                    Text(WorkoutListModel.clockText(point.pace))
                        .font(BrandFonts.number(12))
                        .foregroundStyle(point.row.isCurrent ? BrandColors.accent : BrandColors.text)
                }
            PointMark(x: .value("treino", point.index), y: .value("pace", -point.pace))
                .symbolSize(point.row.isCurrent ? 110 : 55)
                .symbol(Circle().strokeBorder(lineWidth: 2))
                .foregroundStyle(BrandColors.accentFill)
        }
        .chartYScale(domain: -high...(-low))
        .chartYAxis(.hidden)
        .chartXScale(domain: -0.5...(Double(points.count) - 0.5))
        .chartXAxis(.hidden)
        .frame(height: C.similarChartHeight)
        .accessibilityLabel(C.similarChartAccessibility)
        HStack(spacing: 0) {
            ForEach(points, id: \.index) { point in
                VStack(spacing: 1) {
                    Text(point.row.dateText).foregroundStyle(point.row.isCurrent ? BrandColors.accent : BrandColors.dim)
                    if let heartRate = point.row.heartRateText {
                        Text("\(heartRate) bpm").foregroundStyle(BrandColors.rest)
                    }
                }
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}
