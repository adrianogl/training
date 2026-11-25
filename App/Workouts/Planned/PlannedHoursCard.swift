import SwiftUI
import WorkoutAnalysis

struct PlannedHoursCard: View {
    private typealias C = PlannedViewConstants
    let briefing: PlannedBriefing

    var body: some View {
        let coolest = Set(PlannedBriefingBuilder.coolest(briefing.bestHours).map(\.hour))
        let perRow = briefing.bestHours.count > C.hoursPerRow ? C.hoursPerRowLong : max(briefing.bestHours.count, 1)
        return VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: perRow), spacing: 6) {
                ForEach(briefing.bestHours, id: \.hour) { hour in
                    VStack(spacing: 2) {
                        Text("\(Int(hour.temperature.rounded()))°").font(BrandFonts.number(16))
                        Text("\(hour.hour)h").font(.caption2).foregroundStyle(BrandColors.dim)
                        if let extra = briefing.hourHeat[hour.hour] { hourExtra(extra) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(coolest.contains(hour.hour) ? BrandColors.accentFill.opacity(0.18) : BrandColors.track, in: RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous).strokeBorder(coolest.contains(hour.hour) ? BrandColors.accentFill : .clear, lineWidth: 1.5))
                }
            }
            .foregroundStyle(BrandColors.text)
            if !briefing.hourPaces.isEmpty { hourPaces(briefing.hourPaces) }
            if let note = briefing.bestHoursNote {
                Text(note).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func hourExtra(_ seconds: Int) -> some View {
        let color: Color = switch PlannedHourHeat.tone(seconds) {
        case .hot: BrandColors.danger
        case .warm: BrandColors.race
        case .mild: BrandColors.accent
        }
        return Text(seconds > 0 ? String(format: PlannedHourHeatConstants.extraFormat, seconds) : PlannedHourHeatConstants.noExtra)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(color)
    }

    private func hourPaces(_ paces: [BestHourPace]) -> some View {
        VStack(spacing: 6) {
            Divider().overlay(BrandColors.line)
            ForEach(paces, id: \.hour) { pace in
                HStack {
                    Text(String(format: PlannedHourHeatConstants.paceRowFormat, pace.hour)).foregroundStyle(BrandColors.dim)
                    Spacer()
                    Text(String(format: PlannedHourHeatConstants.paceValueFormat, WorkoutFormat.clock(Double(pace.seconds))))
                        .foregroundStyle(BrandColors.text)
                    hourExtra(pace.extra).frame(minWidth: PlannedHourHeatConstants.paceExtraWidth, alignment: .trailing)
                }
                .font(.subheadline)
                .monospacedDigit()
            }
        }
    }
}
