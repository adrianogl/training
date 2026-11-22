import Insights
import SwiftUI

struct TrainerZoneGuideCard: View {
    let bands: [TrainerZoneBand]
    let real: [Int: Double]

    private typealias C = TrainerZoneGuideConstants
    private typealias T = TrainerZoneGuideText

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(C.title).font(.headline).foregroundStyle(BrandColors.text)
            if bands.allSatisfy({ $0.heartRateLow == nil && $0.heartRateHigh == nil }) {
                Text(C.noThreshold).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text(C.zoneHeader)
                    Text(C.heartRateHeader)
                    Text(C.paceHeader)
                    Text(C.usesHeader)
                }
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
                ForEach(bands, id: \.zone) { band in
                    Divider().overlay(BrandColors.line).gridCellUnsizedAxes(.horizontal)
                    GridRow(alignment: .firstTextBaseline) {
                        Text(ZoneText.short(band.zone)).fontWeight(.bold).foregroundStyle(BrandColors.zone(band.zone))
                        Text(ZoneText.heartRate(band) ?? "—").foregroundStyle(BrandColors.text)
                        Text(T.pace(band)).foregroundStyle(band.paceLow == nil ? BrandColors.dim : BrandColors.text)
                        Text(C.uses[band.zone] ?? "").foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.footnote.monospacedDigit())
                }
            }
            if let line = T.realLine(real) {
                Divider().overlay(BrandColors.line)
                VStack(alignment: .leading, spacing: 4) {
                    Text(C.realTitle).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.dim)
                    Text(line).font(.footnote.monospacedDigit()).foregroundStyle(BrandColors.text)
                    if let note = T.realNote(real, bands: bands) {
                        Text(note).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
