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
                DSEmptyState(symbol: C.emptySymbol, title: C.emptyTitle, text: C.emptyText)
            }
            ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                if index > 0 { Divider().overlay(BrandColors.line) }
                Button { onOpen(.edit(snapshot.id)) } label: { row(snapshot) }
                    .buttonStyle(.cardLink)
            }
            if weeklyGoal > 0 {
                if !snapshots.isEmpty { Divider().overlay(BrandColors.line) }
                Button { onOpen(.all) } label: {
                    DSRow(title: C.weeklyTitle, accessory: .chevron) {
                        Text(String(format: C.weeklyPerWeekFormat, weeklyGoal)).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                }
                .buttonStyle(.cardLink)
            }
            Button { onOpen(.all) } label: { CardLinkFooter(title: CardLinkConstants.goals) }
                .buttonStyle(.cardLink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func row(_ snapshot: GoalSnapshot) -> some View {
        DSRow(title: GoalsText.title(snapshot), subtitle: GoalsText.subtitle(snapshot), accessory: .chevron) {
            if let status = GoalsText.status(snapshot) {
                GoalStatusChip(status: status)
            }
        }
    }
}
