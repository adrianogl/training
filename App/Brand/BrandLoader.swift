import SwiftUI

struct BrandLoader: View {
    var size: BrandLoaderSize = .large
    var progress: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let progress {
                tile(start: 0, length: min(max(progress, 0), 1), glow: BrandLoaderConstants.progressGlowOpacity, dim: 1)
                    .animation(.easeOut(duration: BrandLoaderConstants.progressAnimationSeconds), value: progress)
            } else {
                TimelineView(.animation) { context in
                    let seconds = context.date.timeIntervalSinceReferenceDate
                    let metrics = size.metrics
                    let start = reduceMotion ? 0 : BrandLoaderMotion.head(at: seconds)
                    let glow = reduceMotion ? 0 : BrandLoaderMotion.glow(at: seconds) * BrandLoaderConstants.glowPeakOpacity
                    let dim = reduceMotion ? BrandLoaderMotion.reducedOpacity(at: seconds) : 1
                    tile(start: start, length: metrics.traceLength, glow: glow, dim: dim)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SkeletonConstants.loadingLabel)
    }

    private func tile(start: Double, length: Double, glow: Double, dim: Double) -> some View {
        let metrics = size.metrics
        let corner = metrics.side * BrandConstants.iconCornerRatio
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return shape
            .fill(BrandColors.loaderFill)
            .overlay(shape.strokeBorder(BrandColors.loaderEdge, lineWidth: metrics.borderWidth))
            .overlay(
                Text(BrandConstants.logoHighlight)
                    .font(.system(size: metrics.side * BrandLoaderConstants.fontRatio, weight: .black))
                    .foregroundStyle(BrandColors.iconAccent)
            )
            .frame(width: metrics.side, height: metrics.side)
            .shadow(color: BrandColors.iconAccent.opacity(glow), radius: metrics.glowRadius)
            .overlay { ring(start: start, length: length, corner: corner + metrics.ringGap, dim: dim) }
    }

    private func ring(start: Double, length: Double, corner: CGFloat, dim: Double) -> some View {
        let metrics = size.metrics
        let opacities = BrandLoaderConstants.shadowOpacities
        let lime = BrandColors.iconAccent
        let gradient = LinearGradient(
            stops: [
                .init(color: lime.opacity(BrandLoaderConstants.tailOpacity), location: 0),
                .init(color: lime, location: 0.5),
                .init(color: lime.opacity(BrandLoaderConstants.tailOpacity), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return BrandLoaderRing(cornerRadius: corner, start: start, length: length)
            .stroke(gradient, style: StrokeStyle(lineWidth: metrics.ringLineWidth, lineCap: .round))
            .frame(width: metrics.side + metrics.ringGap * 2, height: metrics.side + metrics.ringGap * 2)
            .opacity(BrandLoaderConstants.ringOpacity * dim)
            .shadow(color: lime.opacity(opacities[0] * dim), radius: metrics.shadowRadii[0])
            .shadow(color: lime.opacity(opacities[1] * dim), radius: metrics.shadowRadii[1])
            .shadow(color: lime.opacity(opacities[2] * dim), radius: metrics.shadowRadii[2])
            .allowsHitTesting(false)
    }
}
