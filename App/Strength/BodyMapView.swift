import Insights
import SwiftUI

struct BodyMapView: View {
    let levels: [MuscleGroup: Int]
    var height: CGFloat

    private typealias C = StrengthConstants

    var body: some View {
        HStack(spacing: 4) {
            figure(BodyMapShapes.front, offset: 0)
            figure(BodyMapShapes.back, offset: C.backOffset)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func figure(_ parts: [BodyMapShape], offset: CGFloat) -> some View {
        Canvas { context, size in
            let scale = size.height / C.viewHeight
            let transform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: -offset, y: 0)
            for part in parts {
                context.fill(part.path.applying(transform), with: .color(color(part.slug)))
            }
        }
        .frame(width: height * C.viewWidth / C.viewHeight, height: height)
    }

    private func color(_ slug: String) -> Color {
        if C.skinSlugs.contains(slug) { return C.bodySkin }
        let level = C.slugGroups[slug].map { levels[$0] ?? 0 } ?? 0
        return level > 0 ? C.heat[min(level, C.heat.count) - 1] : C.muscleOff
    }
}

struct BodyMapLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(StrengthText.legend.enumerated()), id: \.offset) { index, text in
                HStack(spacing: 4) {
                    Circle().fill(StrengthConstants.heat[index]).frame(width: 8, height: 8)
                    Text(text)
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(BrandColors.dim)
        .frame(maxWidth: .infinity)
    }
}

struct BodyMapShape: Sendable {
    let slug: String
    let path: Path
}

enum BodyMapShapes {
    static let front = shapes(BodyMapPaths.front)
    static let back = shapes(BodyMapPaths.back)

    private static func shapes(_ parts: [BodyMapPart]) -> [BodyMapShape] {
        parts.map { part in
            var path = Path()
            for data in part.paths { path.addPath(SVGPath.path(data)) }
            return BodyMapShape(slug: part.slug, path: path)
        }
    }
}
