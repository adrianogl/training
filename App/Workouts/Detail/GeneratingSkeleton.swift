import SwiftUI

struct GeneratingSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

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
                Circle()
                    .fill(BrandColors.accentFill)
                    .frame(width: C.pulseDotSize, height: C.pulseDotSize)
                    .opacity(dimmed && !reduceMotion ? C.pulseLowOpacity : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: C.pulseSeconds).repeatForever(), value: dimmed)
                Text(C.generatingLabel)
                    .font(.caption2)
                    .foregroundStyle(BrandColors.dim)
            }
        }
        .onAppear { dimmed = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(C.generatingLabel)
    }
}
