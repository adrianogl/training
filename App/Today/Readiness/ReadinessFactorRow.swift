import SwiftUI

struct ReadinessFactorRow: View {
    let row: ReadinessFactorRowData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Spacer()
                if let pointsText = row.pointsText {
                    Text(pointsText)
                        .font(BrandFonts.number(16))
                        .foregroundStyle(row.group == .down ? BrandColors.attention : BrandColors.ready)
                }
            }
            Text(row.detail)
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
            if let points = row.points {
                DSProgressBar(value: abs(points) / TodayConstants.factorBarFullScale, color: points >= 0 ? BrandColors.ready : BrandColors.attention, height: 5)
            }
        }
        .brandCard()
    }
}
