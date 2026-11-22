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
