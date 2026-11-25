import SwiftUI

struct ScoreLoadingInline: View {
    private typealias C = ScoreLoadingConstants

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ScoreSpinner(size: C.inlineSize, lineWidth: C.inlineLine)
            Text(C.caption)
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(C.accessibility)
    }
}

struct ScoreLoadingBadge: View {
    private typealias C = ScoreLoadingConstants

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            ScoreSpinner(size: C.badgeSize, lineWidth: C.badgeLine)
            Text(C.badgeCaption)
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(C.accessibility)
    }
}

struct ScoreLoadingCard: View {
    let pending: ScorePending
    var showsLabel = true
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = ScoreLoadingConstants

    private var gaugeSize: Double {
        sizeClass == .regular ? WorkoutDetailConstants.scoreGaugeSize : WorkoutDetailConstants.compactScoreGaugeSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsLabel { DSCardLabel(ScoreConstants.breakdownTitle) }
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    ScoreSpinner(size: gaugeSize, lineWidth: C.cardLine)
                    Text(C.cardDots)
                        .font(BrandFonts.number(gaugeSize * C.dotsRatio))
                        .foregroundStyle(BrandColors.dim)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(C.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.text)
                    Text(pending == .weather ? C.weatherReason : C.workoutReason)
                        .font(.footnote)
                        .foregroundStyle(BrandColors.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .brandCard(fillsHeight: true)
        .accessibilityElement(children: .combine)
    }
}
