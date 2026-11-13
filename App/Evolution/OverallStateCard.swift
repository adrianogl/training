import Insights
import SwiftUI

struct OverallStateCard: View {
    let title: String
    let sentence: String
    let indicators: [IndicatorDumbbellData]

    private typealias C = EvolutionConstants

    var body: some View {
        let better = indicators.filter { $0.trend == .better }.count
        let worse = indicators.filter { $0.trend == .worse }.count
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(C.overallTitleWindow).padding(.top, 0).padding(.bottom, 0)
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandColors.text)
            if !indicators.isEmpty {
                HStack(spacing: 2) {
                    ForEach(indicators) { indicator in
                        Rectangle().fill(EvolutionColors.trendFill(indicator.trend))
                    }
                }
                .frame(height: C.tallyHeight)
                .clipShape(Capsule())
                .accessibilityHidden(true)
                Text(String(format: C.tallyFormat, better, indicators.count - better - worse, worse))
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
            }
            if !sentence.isEmpty {
                Text(sentence)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.text.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .brandCard(fillsHeight: true)
    }
}
