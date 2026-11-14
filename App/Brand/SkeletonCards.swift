import SwiftUI

struct SkeletonCards: View {
    let heights: [CGFloat]

    var body: some View {
        VStack(spacing: SkeletonConstants.spacing) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                SkeletonCard(height: height)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SkeletonConstants.loadingLabel)
    }
}

private struct SkeletonCard: View {
    let height: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: SkeletonConstants.lineSpacing) {
            Capsule()
                .fill(BrandColors.track)
                .frame(width: SkeletonConstants.titleBarWidth, height: SkeletonConstants.titleBarHeight)
            RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius / 2, style: .continuous)
                .fill(BrandColors.track)
                .frame(maxHeight: .infinity)
        }
        .padding(BrandConstants.cardPadding)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(BrandColors.card, in: shape)
        .overlay(shape.strokeBorder(BrandColors.cardBorder, lineWidth: 1))
        .shimmer()
        .clipShape(shape)
    }
}
