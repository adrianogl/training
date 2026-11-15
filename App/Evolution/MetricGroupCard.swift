import Charts
import Insights
import SwiftUI

struct MetricGroupCard: View {
    let group: MetricGroup
    let data: [MetricKind: MetricCardData]

    private typealias C = EvolutionConstants

    var body: some View {
        VStack(spacing: TodayConstants.rowSpacing) {
            if let featured = group.featured {
                tile(featured, featured: true)
            }
            ForEach(group.pairs, id: \.first) { pair in
                HStack(alignment: .top, spacing: TodayConstants.rowSpacing) {
                    ForEach(pair, id: \.self) { kind in tile(kind, featured: false) }
                    if pair.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tile(_ kind: MetricKind, featured: Bool) -> some View {
        NavigationLink(value: kind) {
            content(kind, featured: featured)
                .brandCard(fillsHeight: !featured)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func content(_ kind: MetricKind, featured: Bool) -> some View {
        let card = data[kind]
        let change = card.flatMap { EvolutionText.change(kind: kind, stats: $0.stats) }
        let monthly = kind == .monthlyVolume ? card?.monthly ?? [] : []
        VStack(alignment: .leading, spacing: 8) {
            Text(C.metricNames[kind] ?? "")
                .font(featured ? .subheadline.weight(.semibold) : .footnote)
                .foregroundStyle(BrandColors.text)
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(EvolutionText.value(card?.stats.current, C.metricFormats[kind]))
                    .font(BrandFonts.number(featured ? 24 : 16))
                    .foregroundStyle(BrandColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(change?.text ?? C.emptyValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EvolutionColors.trend(change?.trend ?? .unknown))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
            if !monthly.isEmpty {
                MonthlyBars(monthly: monthly)
                    .frame(height: featured ? C.featuredChartHeight : C.monthlyBarHeight)
            } else if featured, let chart = card?.chart, !chart.isEmpty {
                MetricChart(data: chart, style: .featured)
            } else if !featured {
                Sparkline(points: card?.chart.average ?? [], reversed: C.reversedAxis.contains(kind), color: EvolutionColors.trendFill(change?.trend ?? .unknown))
                    .frame(height: C.sparklineHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MonthlyBars: View {
    let monthly: [MonthlyMean]

    var body: some View {
        Chart(Array(monthly.enumerated()), id: \.offset) { index, month in
            BarMark(x: .value("Mês", month.date, unit: .month), y: .value("km", month.value))
                .foregroundStyle(BrandColors.fitness.opacity(index == monthly.count - 1 ? 1 : 0.55))
                .cornerRadius(3)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).locale(WorkoutConstants.locale)).foregroundStyle(BrandColors.dim)
            }
        }
    }
}

struct Sparkline: View {
    let points: [ChartPoint]
    let reversed: Bool
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let values = points.map(\.value)
            if let low = values.min(), let high = values.max(), values.count > 1 {
                let span = max(high - low, .ulpOfOne)
                let y = { (value: Double) -> Double in
                    let ratio = (value - low) / span
                    return (reversed ? ratio : 1 - ratio) * (proxy.size.height - 4) + 2
                }
                let step = proxy.size.width / Double(values.count - 1)
                Path { path in
                    for (index, value) in values.enumerated() {
                        let point = CGPoint(x: Double(index) * step, y: y(value))
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                if let last = values.last {
                    Circle().fill(color).frame(width: 5, height: 5).position(x: proxy.size.width, y: y(last))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
