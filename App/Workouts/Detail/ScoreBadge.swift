import SwiftUI

struct ScoreBadge: View {
    let value: Int
    var size: CGFloat = ScoreConstants.detailBadgeSize

    var body: some View {
        Group {
            if value >= ScoreConstants.perfectScore {
                perfect
            } else {
                regular
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var regular: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(value)")
                .font(BrandFonts.number(size))
                .foregroundStyle(Self.color(for: value))
            Text(ScoreConstants.badgeCaption)
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
        }
    }

    private var perfect: some View {
        VStack(alignment: .center, spacing: 3) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: ScoreConstants.perfectSymbol)
                    .font(.system(size: size * ScoreConstants.perfectSymbolRatio, weight: .bold))
                Text("\(value)")
                    .font(BrandFonts.number(size * ScoreConstants.perfectBadgeRatio))
            }
            .foregroundStyle(BrandColors.onAccent)
            .padding(.leading, 9)
            .padding(.trailing, 12)
            .padding(.vertical, 3)
            .background(BrandColors.accentFill, in: Capsule())
            Text(ScoreConstants.perfectCaption)
                .font(.caption2.weight(.bold))
                .foregroundStyle(BrandColors.accent)
        }
        .fixedSize()
    }

    private var accessibilityText: String {
        let base = "\(ScoreConstants.badgeCaption) \(value)"
        return value >= ScoreConstants.perfectScore ? "\(base), \(ScoreConstants.perfectAccessibility)" : base
    }

    static func color(for value: Int) -> Color {
        if value >= ScoreConstants.strongThreshold { return BrandColors.accent }
        if value >= ScoreConstants.moderateThreshold { return BrandColors.attention }
        return BrandColors.rest
    }
}
