import SwiftUI

struct HeatmapCard: View {
    let columns: [[HeatmapCell]]

    private typealias C = EvolutionConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(C.heatmapTitle).padding(.top, 0).padding(.bottom, 0)
            HStack(spacing: C.heatmapCellSpacing) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: C.heatmapCellSpacing) {
                        ForEach(week) { cell in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(color(cell))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            Text(C.heatmapLegend).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }

    private func color(_ cell: HeatmapCell) -> Color {
        if cell.isFuture { return .clear }
        if cell.kilometers <= 0 { return BrandColors.track }
        return BrandColors.accent.opacity(C.heatmapMinimumOpacity + (1 - C.heatmapMinimumOpacity) * cell.level)
    }
}
