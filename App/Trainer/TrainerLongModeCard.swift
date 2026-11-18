import Insights
import SwiftUI

struct TrainerLongModeCard: View {
    let mode: TrainerLongMode
    let suggestion: TrainerLongSuggestion?
    let onSelect: (TrainerLongMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSCardLabel(TrainerText.longModeTitle)
            Picker(TrainerText.longModeTitle, selection: Binding(get: { mode }, set: onSelect)) {
                ForEach(TrainerConstants.longModes, id: \.self) { option in
                    Text(TrainerText.longModeName(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            if let suggestion {
                Text(TrainerText.longSuggestion(suggestion)).font(.footnote).foregroundStyle(BrandColors.attention)
            }
            Text(TrainerText.longModeHint).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }
}

struct TrainerBestTimeCard: View {
    let bestTime: TrainerBestTime
    let hasBlocks: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DSCardLabel(TrainerText.bestTimeTitle)
                Spacer()
                Text(TrainerText.bestTimeCaption).font(.caption).foregroundStyle(BrandColors.dim)
            }
            HStack {
                Text(TrainerText.bestTimeStart(bestTime.hour)).font(.subheadline).foregroundStyle(BrandColors.text)
                Spacer()
                Text(TrainerText.temperature(bestTime.temperature))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(bestTime.heat.isHot ? BrandColors.attention : BrandColors.accent)
                    .monospacedDigit()
            }
            if bestTime.heat.isHot {
                Text(TrainerText.heatWarning(bestTime.heat, hasBlocks: hasBlocks)).font(.footnote).foregroundStyle(BrandColors.dim)
            } else if let later = bestTime.laterHotHour {
                Text(TrainerText.heatLater(hour: later, hasBlocks: hasBlocks)).font(.footnote).foregroundStyle(BrandColors.dim)
            }
        }
        .brandCard()
    }
}
