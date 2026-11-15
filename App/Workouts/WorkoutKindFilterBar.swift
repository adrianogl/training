import SwiftUI

struct WorkoutKindFilterBar: View {
    @Binding var selection: WorkoutKindFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(WorkoutKindFilter.allCases) { filter in
                    let chosen = selection == filter
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = filter }
                    } label: {
                        Text(WorkoutConstants.filterTitles[filter] ?? "")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(chosen ? BrandColors.accent : BrandColors.dim)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(chosen ? BrandColors.accentGlow : BrandColors.track, in: Capsule())
                            .overlay(Capsule().strokeBorder(chosen ? BrandColors.accentFill.opacity(0.4) : BrandColors.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }
}
