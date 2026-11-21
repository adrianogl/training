import Insights
import SwiftUI

struct StrengthFocusChips: View {
    @Binding var selection: TrainerStrengthGroup

    private typealias C = TrainerStrengthConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TrainerStrengthText.focusLabel).font(.caption.weight(.bold)).foregroundStyle(BrandColors.dim)
            VStack(spacing: C.dayButtonSpacing) {
                ForEach(C.focusRows, id: \.self) { row in
                    HStack(spacing: C.dayButtonSpacing) {
                        ForEach(row, id: \.self) { group in chip(group) }
                    }
                }
            }
        }
    }

    private func chip(_ group: TrainerStrengthGroup) -> some View {
        let selected = group == selection
        return Button { selection = group } label: {
            Text(TrainerStrengthText.focusName(group))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? BrandColors.onAccent : BrandColors.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, DSSpacing.s2)
                .frame(maxWidth: .infinity, minHeight: C.dayButtonSize)
                .background(selected ? BrandColors.accentFill : BrandColors.track, in: RoundedRectangle(cornerRadius: C.chipRadius, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
