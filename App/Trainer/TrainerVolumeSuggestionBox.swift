import Insights
import SwiftUI

struct TrainerVolumeSuggestionBox: View {
    let suggestion: TrainerVolumeSuggestion
    let inUse: Bool
    let use: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(TrainerText.volumeSuggestionTitle(start: suggestion.startMeters, peak: suggestion.peakMeters))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.accent).monospacedDigit()
                Spacer()
                if inUse {
                    Text(TrainerText.volumeSuggestionInUse).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.accent)
                } else {
                    Button(TrainerText.volumeSuggestionUse, action: use).buttonStyle(DSButtonStyle(role: .text))
                }
            }
            Text(TrainerText.volumeSuggestionReason(suggestion)).font(.footnote).foregroundStyle(BrandColors.dim)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BrandColors.accentGlow, in: RoundedRectangle(cornerRadius: TrainerConstants.suggestionRadius, style: .continuous))
    }
}
