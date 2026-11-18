import SwiftUI

enum DSLegendMark {
    case line, dashed, square
}

struct DSLegendItem: View {
    let text: String
    let color: Color
    var mark: DSLegendMark = .line

    var body: some View {
        HStack(spacing: DSSpacing.s1 + 1) {
            swatch
            Text(text).font(.caption2).foregroundStyle(BrandColors.dim)
        }
    }

    @ViewBuilder
    private var swatch: some View {
        switch mark {
        case .line:
            Capsule().fill(color).frame(width: DSLegendConstants.lineWidth, height: DSLegendConstants.lineHeight)
        case .dashed:
            Capsule()
                .strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: DSLegendConstants.lineWidth, height: DSLegendConstants.dashedHeight)
        case .square:
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: DSLegendConstants.square, height: DSLegendConstants.square)
        }
    }
}
