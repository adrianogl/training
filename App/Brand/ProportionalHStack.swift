import SwiftUI

struct ProportionalHStack: Layout {
    var weights: [Double]
    var spacing: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let widths = columnWidths(total: width, count: subviews.count)
        let height = zip(subviews, widths).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = columnWidths(total: bounds.width, count: subviews.count)
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    private func columnWidths(total: Double, count: Int) -> [Double] {
        guard count > 0 else { return [] }
        let used = Array(weights.prefix(count)) + Array(repeating: 1, count: max(0, count - weights.count))
        let sum = used.reduce(0, +)
        let available = max(0, total - spacing * Double(count - 1))
        return used.map { available * $0 / sum }
    }
}
