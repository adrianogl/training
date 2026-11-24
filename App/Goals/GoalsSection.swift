import Storage
import SwiftData
import SwiftUI

struct GoalsSection: View {
    @Query(filter: #Predicate<GoalRecord> { $0.deletedAt == nil }, sort: \GoalRecord.createdAt) private var goals: [GoalRecord]

    private typealias C = GoalsConstants

    var body: some View {
        let active = goals.filter { !$0.archived && $0.goalKind != nil }
        let archived = goals.filter { $0.archived && $0.goalKind != nil }
        Section {
            if active.isEmpty {
                DSEmptyState(symbol: C.emptySymbol, title: C.empty, text: C.emptyText)
            }
            ForEach(active) { goal in row(goal) }
            NavigationLink {
                GoalEditorView(goalId: nil)
            } label: {
                Label(C.newGoal, systemImage: "plus.circle.fill").foregroundStyle(BrandColors.accent)
            }
        } header: {
            DSSectionTitle(C.sectionTitle)
        } footer: {
            Text(C.footer)
        }
        if !archived.isEmpty {
            Section {
                ForEach(archived) { goal in row(goal) }
            } header: {
                DSSectionTitle(C.archivedTitle)
            }
        }
    }

    private func row(_ goal: GoalRecord) -> some View {
        NavigationLink {
            GoalEditorView(goalId: goal.id)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(GoalsText.title(goal)).font(.body.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(GoalsText.line(goal)).font(.caption).foregroundStyle(BrandColors.dim)
                Text(C.kindScopes[goal.goalKind ?? .time] ?? "").font(.caption).foregroundStyle(BrandColors.dim)
            }
        }
    }
}
