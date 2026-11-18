import SwiftUI

struct DSFilterChip: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? BrandColors.accent : BrandColors.text.opacity(DSFilterChipConstants.idleTextOpacity))
                .lineLimit(1)
                .padding(.horizontal, DSFilterChipConstants.horizontalPadding)
                .frame(height: DSFilterChipConstants.height)
                .background(isSelected ? BrandColors.accentGlow : BrandColors.track, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? BrandColors.accentFill.opacity(DSFilterChipConstants.selectedBorderOpacity) : BrandColors.line, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.cardLink)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
