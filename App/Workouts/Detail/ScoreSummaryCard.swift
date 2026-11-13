import SwiftUI

struct ScoreSummaryCard: View {
    let value: Int
    let rows: [ScoreRowData]
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = WorkoutDetailConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(ScoreConstants.breakdownTitle).padding(.top, 0).padding(.bottom, 0)
            HStack(alignment: .center, spacing: 18) {
                ScoreGauge(
                    score: value,
                    size: sizeClass == .regular ? C.scoreGaugeSize : C.compactScoreGaugeSize,
                    moderate: ScoreConstants.moderateThreshold,
                    hard: ScoreConstants.strongThreshold,
                    accessibilityName: ScoreConstants.breakdownTitle
                )
                VStack(spacing: 10) {
                    ForEach(rows.filter(\.isIncluded)) { row in
                        HStack(spacing: 10) {
                            Text(row.name)
                                .font(.footnote)
                                .foregroundStyle(BrandColors.dim)
                                .frame(width: C.scorePartNameWidth, alignment: .leading)
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(color(row))
                                    .frame(width: max(4, proxy.size.width * row.points / row.maximum))
                            }
                            .frame(height: C.scorePartBarHeight)
                            .background(BrandColors.track, in: Capsule())
                            Text(row.pointsText ?? "")
                                .font(BrandFonts.number(14))
                                .foregroundStyle(BrandColors.text)
                                .fixedSize()
                        }
                    }
                }
            }
            let reasons = rows.compactMap { row in row.reasonText.map { (text: $0, full: row.points >= row.maximum) } }
            if !reasons.isEmpty {
                FlowChips(items: reasons.map { ($0.text, $0.full ? BrandColors.accent : BrandColors.attention) })
            }
        }
        .brandCard(fillsHeight: true)
    }

    private func color(_ row: ScoreRowData) -> Color {
        row.points < row.maximum ? BrandColors.attention : BrandColors.accentFill
    }
}

struct FlowChips: View {
    let items: [(String, Color)]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    private var chips: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            Text(item.0)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(item.1.opacity(0.14), in: Capsule())
        }
    }
}
