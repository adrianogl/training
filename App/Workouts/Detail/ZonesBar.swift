import SwiftUI

struct ZonesBar: View {
    let shares: [ZoneShare]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(shares.filter { $0.share > 0 }, id: \.zone) { item in
                        Rectangle()
                            .fill(BrandColors.zone(item.zone))
                            .frame(width: max(0, proxy.size.width * item.share - 2))
                    }
                }
            }
            .frame(height: WorkoutDetailConstants.zoneBarHeight)
            .clipShape(Capsule())
            HStack(alignment: .top, spacing: 0) {
                ForEach(shares, id: \.zone) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(BrandColors.zone(item.zone))
                                .frame(width: 6, height: 6)
                            Text("Z\(item.zone)")
                                .font(.caption2)
                                .foregroundStyle(BrandColors.dim)
                        }
                        Text(minutes(item))
                            .font(BrandFonts.number(15))
                            .foregroundStyle(item.share > 0 ? BrandColors.text : BrandColors.dim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            Text("Tempo abaixo da Z1 não entra na barra.")
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
        }
        .glassCard()
    }

    private func minutes(_ item: ZoneShare) -> String {
        if item.share > 0, item.seconds < WorkoutDetailConstants.secondsPerMinute / 2 {
            return "< 1 min"
        }
        return "\(Int((item.seconds / WorkoutDetailConstants.secondsPerMinute).rounded())) min"
    }
}
