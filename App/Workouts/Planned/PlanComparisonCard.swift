import SwiftUI

struct PlanComparisonCard: View {
    let rows: [BriefingComparison]
    let note: String?
    var title = PlannedViewConstants.comparison
    var framed = true
    var showsLabel = true

    private typealias C = PlannedViewConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsLabel {
                HStack {
                    DSCardLabel(title)
                    Spacer()
                    score
                }
            }
            HStack {
                if !showsLabel { score }
                Spacer()
                Text(C.planned).frame(width: C.compareColumn, alignment: .trailing)
                Text(C.done).frame(width: C.compareColumn, alignment: .trailing)
                Color.clear.frame(width: 20, height: 1)
            }
            .font(.caption2).foregroundStyle(BrandColors.dim)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.label).font(.subheadline)
                    Spacer()
                    Text(row.planned).font(BrandFonts.number(14)).foregroundStyle(BrandColors.dim).frame(width: C.compareColumn, alignment: .trailing)
                    Text(row.done).font(BrandFonts.number(14)).frame(width: C.compareColumn, alignment: .trailing)
                    Image(systemName: row.ok ? "checkmark" : "exclamationmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(row.ok ? BrandColors.accent : BrandColors.attention)
                        .frame(width: 20)
                }
                .foregroundStyle(BrandColors.text)
            }
            if let note {
                Text(note).font(.caption).foregroundStyle(BrandColors.dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(framed: framed)
    }

    private var score: some View {
        DSChip(text: String(format: C.compareScoreFormat, rows.filter(\.ok).count, rows.count), tone: rows.allSatisfy(\.ok) ? .accent : .attention)
    }
}
