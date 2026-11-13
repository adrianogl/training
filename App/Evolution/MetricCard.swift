import Insights
import SwiftUI

struct MetricCard: View {
    let kind: MetricKind
    let data: MetricCardData?
    let chart: MetricChartData?

    var body: some View {
        NavigationLink(value: kind) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(EvolutionConstants.metricNames[kind] ?? "").padding(.top, 0).padding(.bottom, 0)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(EvolutionText.value(data?.stats.current, EvolutionConstants.metricFormats[kind]))
                        .font(BrandFonts.number(26))
                        .foregroundStyle(BrandColors.text)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    if let data, let change = EvolutionText.change(kind: kind, stats: data.stats) {
                        Text(change.text)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EvolutionColors.trend(change.trend))
                            .lineLimit(1)
                    }
                }
                if let chart, !chart.isEmpty {
                    MetricChart(data: chart, style: .compact)
                } else {
                    Color.clear.frame(height: EvolutionConstants.cardChartHeight)
                }
            }
            .brandCard()
        }
        .buttonStyle(.plain)
    }
}
