import SwiftUI

struct ScoreBreakdownView: View {
    let rows: [ScoreRowData]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandColors.text)
                        Spacer()
                        if let pointsText = row.pointsText {
                            Text(pointsText)
                                .font(BrandFonts.number(16))
                                .foregroundStyle(row.points < row.maximum ? BrandColors.attention : BrandColors.accent)
                        }
                    }
                    if let reason = row.reasonText {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(BrandColors.dim)
                    }
                    if row.isIncluded {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(row.points < row.maximum ? BrandColors.attention : BrandColors.accent)
                                .frame(width: max(4, proxy.size.width * row.points / row.maximum))
                        }
                        .frame(height: 5)
                        .background(BrandColors.track, in: Capsule())
                    }
                }
                .brandCard()
            }
        }
    }
}
