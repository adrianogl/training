import SwiftUI

struct WorkoutKindFilterBar: View {
    @Binding var selection: WorkoutKindFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(WorkoutKindFilter.allCases) { filter in
                    DSFilterChip(title: WorkoutConstants.filterTitles[filter] ?? "", isSelected: selection == filter) {
                        withAnimation(.easeInOut(duration: 0.2)) { selection = filter }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }
}
