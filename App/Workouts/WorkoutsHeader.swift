import SwiftUI

struct WorkoutsHeader: View {
    @Binding var modeRaw: String
    let onPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DSScreenHeader(title: WorkoutConstants.listTitle) {
                SyncStatusPill()
            } trailing: {
                Button(action: onPlan) {
                    Label(WorkoutCalendarConstants.planButton, systemImage: "list.bullet.clipboard")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(BrandColors.accent)
                .controlSize(.small)
            }
            Picker(WorkoutCalendarConstants.modeNames[.week] ?? "", selection: $modeRaw) {
                ForEach(WorkoutListMode.allCases) { Text(WorkoutCalendarConstants.modeNames[$0] ?? "").tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }
}
