import Insights
import SwiftUI

struct IndicatorsCard: View {
    let indicators: [IndicatorDumbbellData]
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = EvolutionConstants

    var body: some View {
        let regular = sizeClass == .regular
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(C.indicatorsTitle).padding(.top, 0).padding(.bottom, 0)
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Text(C.indicatorsLegend).frame(width: regular ? C.dumbbellWidth : C.compactDumbbellWidth, alignment: .leading)
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
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(indicator.name).font(.footnote).foregroundStyle(BrandColors.text)
                        if indicator.windowed {
                            Text(C.windowedToday).font(.system(size: 10)).foregroundStyle(BrandColors.dim)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Dumbbell(data: indicator)
                        .frame(width: regular ? C.dumbbellWidth : C.compactDumbbellWidth, height: C.dumbbellHeight)
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
            Text(C.indicatorsFootnote)
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
                .padding(.top, 4)
        }
        .brandCard()
    }
}

private struct Dumbbell: View {
    let data: IndicatorDumbbellData

    var body: some View {
        let values = [data.then, data.today, data.goal].compactMap { $0 }
        GeometryReader { proxy in
            if let low = values.min(), let high = values.max() {
                let pad = max((high - low) * EvolutionConstants.dumbbellPaddingRatio, abs(high) * 0.01, 0.001)
                let lo = low - pad, hi = high + pad
                let width = proxy.size.width
                let midY = proxy.size.height / 2
                let x = { (value: Double) -> Double in
                    let ratio = (value - lo) / (hi - lo)
                    return (data.lowerIsBetter ? 1 - ratio : ratio) * width
                }
                let fill = EvolutionColors.trendFill(data.trend)
                ZStack(alignment: .topLeading) {
                    Capsule().fill(BrandColors.track).frame(width: width, height: 2).position(x: width / 2, y: midY)
                    if let goal = data.goal {
                        Capsule().fill(BrandColors.accent).frame(width: 2, height: proxy.size.height).position(x: x(goal), y: midY)
                    }
                    if let then = data.then, let today = data.today {
                        Capsule().fill(fill.opacity(0.6))
                            .frame(width: abs(x(today) - x(then)), height: 4)
                            .position(x: (x(today) + x(then)) / 2, y: midY)
                    }
                    if let then = data.then {
                        Circle().fill(BrandColors.background)
                            .overlay(Circle().strokeBorder(BrandColors.dim, lineWidth: 1.5))
                            .frame(width: 9, height: 9)
                            .position(x: x(then), y: midY)
                    }
                    if let today = data.today {
                        Circle().fill(fill).frame(width: 11, height: 11).position(x: x(today), y: midY)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
