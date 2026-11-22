import SwiftUI

struct PlannedPhaseRow: View {
    let phase: BriefingPhase
    @Environment(\.planZones) private var zones

    private typealias C = PlannedViewConstants

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.when).font(BrandFonts.number(15)).foregroundStyle(BrandColors.text).lineLimit(1).minimumScaleFactor(0.8)
                if let length = phase.length {
                    Text(length).font(.caption2).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: C.phaseColumn, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(phase.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
                    if let zone = phase.zone {
                        ZoneChip(zone: zone, band: zones?.band(zone))
                    }
                }
                if !phase.detail.isEmpty {
                    Text(phase.detail).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
