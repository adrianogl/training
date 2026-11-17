import SwiftUI

struct ScoreInline: View {
    let value: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(value)")
                .font(BrandFonts.number(ScoreConstants.rowInlineSize))
                .foregroundStyle(ScoreBadge.color(for: value))
            Text(ScoreConstants.badgeCaption)
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ScoreConstants.badgeCaption) \(value)")
    }
}
