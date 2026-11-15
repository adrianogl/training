import SwiftUI

struct ZoneStrip: View {
    let shares: [Double]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(Array(shares.enumerated()), id: \.offset) { index, share in
                    if share > 0 {
                        Rectangle()
                            .fill(BrandColors.zone(index + 1))
                            .frame(width: max(1, proxy.size.width * share - 1))
                    }
                }
            }
        }
        .frame(height: TodayConstants.zoneStripHeight)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}
