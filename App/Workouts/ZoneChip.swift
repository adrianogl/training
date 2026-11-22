import Insights
import SwiftUI

struct ZoneChip: View {
    let zone: Int
    var band: TrainerZoneBand?
    var compact = false

    var body: some View {
        Text(compact ? ZoneText.short(zone) : ZoneText.label(zone, band: band))
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(BrandColors.zone(zone))
            .padding(.horizontal, DSChipConstants.horizontalPadding)
            .frame(height: DSChipConstants.height)
            .background(BrandColors.zone(zone).opacity(DSChipConstants.softOpacity), in: Capsule())
            .fixedSize()
    }
}
