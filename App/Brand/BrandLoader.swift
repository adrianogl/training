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
        let shape = RoundedRectangle(cornerRadius: metrics.side * BrandConstants.iconCornerRatio, style: .continuous)
        return shape
            .fill(BrandColors.loaderFill)
            .overlay(shape.strokeBorder(BrandColors.loaderEdge, lineWidth: metrics.borderWidth))
            .overlay(TrackGlyph(size: metrics.side, trackOpacity: TrackGlyphConstants.loaderTrackOpacity, showsRunner: false))
            .overlay(alignment: .topLeading) { lap(start: start, length: length, dim: dim) }
            .frame(width: metrics.side, height: metrics.side)
            .shadow(color: BrandColors.iconAccent.opacity(glow), radius: metrics.glowRadius)
    }

    private func lap(start: Double, length: Double, dim: Double) -> some View {
        TrackLap(side: size.metrics.side, start: start, length: length, glowRadii: size.metrics.shadowRadii)
            .opacity(BrandLoaderConstants.ringOpacity * dim)
    }
}
