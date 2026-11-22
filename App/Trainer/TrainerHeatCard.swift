import Insights
import SwiftUI

struct TrainerHeatCard: View {
    let day: TrainerHeatDay
    @Binding var selected: Int?
    let hasBlocks: Bool

    private typealias C = TrainerConstants

    private var current: Int { selected ?? day.usualHour }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DSCardLabel(TrainerText.heatTitle)
                Spacer()
                Text(TrainerText.bestTimeCaption).font(.caption).foregroundStyle(BrandColors.dim)
            }
            strip
            if let hour = day.hour(current) {
                HStack {
                    Text(TrainerText.heatHourLabel(hour.hour, usual: hour.hour == day.usualHour)).font(.subheadline).foregroundStyle(BrandColors.text)
                    Spacer()
                    Text(TrainerText.heatConditions(hour))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(hour.heat.isHot ? BrandColors.attention : BrandColors.accent)
                        .monospacedDigit()
                }
                Text(TrainerText.heatEffect(hour, day: day, hasBlocks: hasBlocks)).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            if current == day.usualHour, let hour = day.suggestedHour.flatMap(day.hour), let usual = day.hour(day.usualHour) {
                Button { selected = hour.hour } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(TrainerText.heatHourLabel(hour.hour, usual: false))
                            Spacer()
                            Text(TrainerText.heatSwapConditions(hour)).monospacedDigit()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.accent)
                        Text(TrainerText.heatSwapGain(usual.heat.paceOffset - hour.heat.paceOffset))
                            .font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(BrandColors.accentGlow, in: RoundedRectangle(cornerRadius: C.heatSwapRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            if current != day.usualHour {
                Button(TrainerText.heatReset) { selected = nil }
                    .font(.footnote)
                    .foregroundStyle(BrandColors.accent)
                    .buttonStyle(.plain)
            }
        }
        .brandCard()
    }

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(day.hours) { hour in
                        chip(hour).id(hour.hour)
                    }
                }
            }
            .onAppear { proxy.scrollTo(current, anchor: .center) }
            .onChange(of: current) { _, value in withAnimation { proxy.scrollTo(value, anchor: .center) } }
        }
    }

    private func chip(_ hour: TrainerHeatHour) -> some View {
        let isSelected = hour.hour == current
        let shape = RoundedRectangle(cornerRadius: C.heatChipRadius, style: .continuous)
        return Button { selected = hour.hour == day.usualHour ? nil : hour.hour } label: {
            VStack(spacing: 1) {
                Text(TrainerText.heatChipHour(hour.hour)).font(.caption2).foregroundStyle(BrandColors.dim)
                Text(TrainerText.heatChipTemperature(hour.temperature)).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.text).monospacedDigit()
                Text(TrainerText.heatChipEffect(hour.heat)).font(.caption2.weight(.semibold))
                    .foregroundStyle(hour.heat.isHot ? BrandColors.attention : BrandColors.accent).monospacedDigit()
                Text(hour.hour == day.usualHour ? TrainerText.heatUsualMark : " ").font(.caption2).foregroundStyle(BrandColors.accent)
            }
            .frame(width: C.heatChipWidth)
            .padding(.vertical, 6)
            .background(isSelected ? BrandColors.accentGlow : BrandColors.track, in: shape)
            .overlay { if isSelected { shape.strokeBorder(BrandColors.accent, lineWidth: 1) } }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
