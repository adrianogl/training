import SwiftUI

struct GeneratingSkeleton: View {
    private typealias C = DetailedScreenConstants

    var body: some View {
        VStack(alignment: .leading, spacing: C.skeletonLineSpacing) {
            VStack(alignment: .leading, spacing: C.skeletonLineSpacing) {
                ForEach(Array(C.skeletonWidths.enumerated()), id: \.offset) { _, width in
                    RoundedRectangle(cornerRadius: C.skeletonLineHeight / 2, style: .continuous)
                        .fill(BrandColors.track)
                        .frame(height: C.skeletonLineHeight)
                        .scaleEffect(x: width, anchor: .leading)
                }
            }
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: C.skeletonLineHeight / 2, style: .continuous))
            HStack(spacing: 6) {
                BrandLoader(size: .mini)
                Text(C.generatingLabel)
                    .font(.caption2)
                    .foregroundStyle(BrandColors.dim)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(C.generatingLabel)
    }
}
