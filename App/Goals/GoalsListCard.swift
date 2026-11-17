import Insights
import SwiftUI

struct GoalsListCard: View {
    let snapshots: [GoalSnapshot]
    let onOpen: (GoalSheet) -> Void
    @AppStorage(AppConstants.weeklyGoalDefaultsKey) private var weeklyGoal = 0

    private typealias C = GoalsConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if snapshots.isEmpty && weeklyGoal == 0 {
                Text(C.empty).font(.subheadline).foregroundStyle(BrandColors.dim)
            }
            ForEach(snapshots, id: \.id) { snapshot in
                Button { onOpen(.edit(snapshot.id)) } label: { row(snapshot) }
                    .buttonStyle(.plain)
                Divider().overlay(BrandColors.line)
            }
            if weeklyGoal > 0 {
                Button { onOpen(.all) } label: {
                    HStack {
                        Text(C.weeklyTitle).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                        Spacer()
                        Text(String(format: C.weeklyPerWeekFormat, weeklyGoal)).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().overlay(BrandColors.line)
            }
            HStack {
                Button(C.newGoalPlus) { onOpen(.new) }
                    .foregroundStyle(BrandColors.accent)
                Spacer()
                Button(C.allGoals) { onOpen(.all) }
                    .foregroundStyle(BrandColors.dim)
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func row(_ snapshot: GoalSnapshot) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(GoalsText.title(snapshot)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(GoalsText.subtitle(snapshot)).font(.caption).foregroundStyle(BrandColors.dim).monospacedDigit()
            }
            Spacer(minLength: 8)
            if let status = GoalsText.status(snapshot) {
                GoalStatusChip(status: status)
            }
        }
        .contentShape(Rectangle())
    }
}
