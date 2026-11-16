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
        let metrics = size.metrics
        let unit = metrics.side / TrackGlyphConstants.canvas
        let track = TrackGlyphConstants.outer.scaled(by: unit)
        let corner = track.height / 2
        let runner = TrackGlyphConstants.runner.width * unit
        let head = Self.point(on: track.size, corner: corner, at: start + length)
        let opacities = BrandLoaderConstants.shadowOpacities
        let lime = BrandColors.iconAccent
        return ZStack(alignment: .topLeading) {
            BrandLoaderRing(cornerRadius: corner, start: start, length: length)
                .stroke(lime, style: StrokeStyle(lineWidth: TrackGlyphConstants.outerLineWidth * unit, lineCap: .round))
                .shadow(color: lime.opacity(opacities[0]), radius: metrics.shadowRadii[0])
                .shadow(color: lime.opacity(opacities[1]), radius: metrics.shadowRadii[1])
                .shadow(color: lime.opacity(opacities[2]), radius: metrics.shadowRadii[2])
            if length > 0 {
                Circle()
                    .fill(BrandColors.iconRunner)
                    .frame(width: runner, height: runner)
                    .offset(x: head.x - runner / 2, y: head.y - runner / 2)
            }
        }
        .frame(width: track.width, height: track.height, alignment: .topLeading)
        .offset(x: track.minX, y: track.minY)
        .opacity(BrandLoaderConstants.ringOpacity * dim)
        .allowsHitTesting(false)
    }

    private static func point(on size: CGSize, corner: CGFloat, at fraction: Double) -> CGPoint {
        let rect = CGRect(origin: .zero, size: size)
        let wrapped = fraction.truncatingRemainder(dividingBy: 1)
        let outline = BrandLoaderRing.outline(in: rect, cornerRadius: corner)
        return outline.trimmedPath(from: 0, to: wrapped).currentPoint ?? CGPoint(x: rect.midX, y: rect.minY)
    }
}
