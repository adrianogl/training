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
                        .foregroundStyle(row.group == .down ? BrandColors.attention : BrandColors.accent)
                }
            }
            Text(row.detail)
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
            if let points = row.points {
                GeometryReader { proxy in
                    Capsule()
                        .fill(points >= 0 ? BrandColors.accent : BrandColors.attention)
                        .frame(width: max(4, proxy.size.width * min(abs(points) / TodayConstants.factorBarFullScale, 1)))
                }
                .frame(height: 5)
                .background(BrandColors.track, in: Capsule())
            }
        }
        .brandCard()
    }
}
