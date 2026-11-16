import SwiftUI

struct StrengthSparkline: View {
    let values: [Double]
    var color: Color = BrandColors.accent

    var body: some View {
        Canvas { context, size in
            guard let low = values.min(), let high = values.max() else { return }
            let span = max(high - low, 1)
            let inset: CGFloat = 3
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: values.count == 1 ? size.width - inset : inset + CGFloat(index) * (size.width - inset * 2) / CGFloat(values.count - 1),
                    y: values.count == 1 ? size.height / 2 : size.height - inset - CGFloat((value - low) / span) * (size.height - inset * 2)
                )
            }
            var path = Path()
            path.addLines(points)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            if let last = points.last {
                context.fill(Path(ellipseIn: CGRect(x: last.x - 3, y: last.y - 3, width: 6, height: 6)), with: .color(color))
            }
        }
        .frame(width: StrengthConstants.sparkWidth, height: StrengthConstants.sparkLineHeight)
        .accessibilityHidden(true)
    }
}
