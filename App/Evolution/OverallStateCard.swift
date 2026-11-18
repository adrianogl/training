import Insights
import SwiftUI

struct OverallStateCard: View {
    let title: String
    let sentence: String
    let indicators: [IndicatorDumbbellData]
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = EvolutionConstants

    var body: some View {
        let regular = sizeClass == .regular
        VStack(alignment: .leading, spacing: 12) {
            DSCardLabel(C.overallTitleWindow)
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandColors.text)
            if !sentence.isEmpty {
                Text(sentence)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.text.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !indicators.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        Text(C.columnToday).frame(width: C.indicatorValueWidth, alignment: .trailing)
                        Text(C.columnDelta).frame(width: C.indicatorDeltaWidth, alignment: .trailing)
                        if regular { Text(C.columnGoal).frame(width: C.indicatorGoalWidth, alignment: .trailing) }
                    }
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(BrandColors.dim)
                    ForEach(indicators) { indicator in
                        Divider().overlay(BrandColors.line)
                        row(indicator, regular: regular)
                    }
                }
            }
        }
        .brandCard()
    }

    private func row(_ indicator: IndicatorDumbbellData, regular: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(indicator.name).font(.footnote).foregroundStyle(BrandColors.text)
                if indicator.windowed {
                    Text(C.windowedToday).font(.system(size: 10)).foregroundStyle(BrandColors.dim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(indicator.todayText)
                .font(BrandFonts.number(15))
                .foregroundStyle(BrandColors.text)
                .frame(width: C.indicatorValueWidth, alignment: .trailing)
            Text(indicator.deltaText ?? C.emptyValue)
                .font(BrandFonts.number(14))
                .foregroundStyle(EvolutionColors.trend(indicator.trend))
                .frame(width: C.indicatorDeltaWidth, alignment: .trailing)
            if regular {
                Text(indicator.goalText ?? C.emptyValue)
                    .font(BrandFonts.number(14))
                    .foregroundStyle(indicator.goalText == nil ? BrandColors.dim : (indicator.goalPending ? BrandColors.attention : BrandColors.accent))
                    .frame(width: C.indicatorGoalWidth, alignment: .trailing)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}
