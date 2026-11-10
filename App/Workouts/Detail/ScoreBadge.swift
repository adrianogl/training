import SwiftUI

struct ScoreBadge: View {
    let value: Int
    var size: CGFloat = ScoreConstants.detailBadgeSize

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(value)")
                .font(BrandFonts.number(size))
                .foregroundStyle(Self.color(for: value))
            Text(ScoreConstants.badgeCaption)
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ScoreConstants.badgeCaption) \(value)")
    }

    static func color(for value: Int) -> Color {
        if value >= ScoreConstants.strongThreshold { return BrandColors.accent }
        if value >= ScoreConstants.moderateThreshold { return BrandColors.attention }
        return BrandColors.rest
    }
}
