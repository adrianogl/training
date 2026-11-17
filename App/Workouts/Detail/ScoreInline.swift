import SwiftUI

struct ScoreInline: View {
    let value: Int

    var body: some View {
        Group {
            if value >= ScoreConstants.perfectScore {
                perfect
            } else {
                regular
            }
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var regular: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(value)")
                .font(BrandFonts.number(ScoreConstants.rowInlineSize))
                .foregroundStyle(ScoreBadge.color(for: value))
            Text(ScoreConstants.badgeCaption)
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
        }
    }

    private var perfect: some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: ScoreConstants.perfectSymbol)
                .font(.system(size: ScoreConstants.perfectSymbolSize, weight: .bold))
            Text("\(value)")
                .font(BrandFonts.number(ScoreConstants.perfectInlineSize))
        }
        .foregroundStyle(BrandColors.onAccent)
        .padding(.leading, 6)
        .padding(.trailing, 9)
        .padding(.vertical, 1)
        .background(BrandColors.accentFill, in: Capsule())
    }

    private var accessibilityText: String {
        let base = "\(ScoreConstants.badgeCaption) \(value)"
        return value >= ScoreConstants.perfectScore ? "\(base), \(ScoreConstants.perfectAccessibility)" : base
    }
}
