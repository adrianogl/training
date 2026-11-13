import Charts
import Insights
import SwiftUI

struct MetricGroupCard: View {
    let group: MetricGroup
    let data: [MetricKind: MetricCardData]
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = EvolutionConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(group.title).padding(.top, 0).padding(.bottom, 6)
            ForEach(Array(group.kinds.enumerated()), id: \.element) { index, kind in
                if index > 0 { Divider().overlay(BrandColors.line) }
                NavigationLink(value: kind) {
                    row(kind)
                }
                .buttonStyle(.plain)
            }
        }
        .brandCard(fillsHeight: true)
    }

    @ViewBuilder
    private func row(_ kind: MetricKind) -> some View {
        let card = data[kind]
        let change = card.flatMap { EvolutionText.change(kind: kind, stats: $0.stats) }
        let showsMonthly = kind == .monthlyVolume && !(card?.monthly.isEmpty ?? true)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(C.metricNames[kind] ?? "")
                    .font(.footnote)
                    .foregroundStyle(BrandColors.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !showsMonthly {
                    Sparkline(points: card?.chart.average ?? [], reversed: C.reversedAxis.contains(kind), color: EvolutionColors.trendFill(change?.trend ?? .unknown))
                        .frame(minWidth: C.sparklineMinWidth, maxWidth: sizeClass == .regular ? C.sparklineWidth : C.compactSparklineWidth)
                        .frame(height: C.sparklineHeight)
                }
                Text(EvolutionText.value(card?.stats.current, C.metricFormats[kind]))
                    .font(BrandFonts.number(16))
                    .foregroundStyle(BrandColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(width: C.metricValueWidth, alignment: .trailing)
                Text(change?.text ?? C.emptyValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EvolutionColors.trend(change?.trend ?? .unknown))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(width: C.metricChangeWidth, alignment: .trailing)
            }
            if showsMonthly, let monthly = card?.monthly {
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
                .frame(height: C.monthlyBarHeight)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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
