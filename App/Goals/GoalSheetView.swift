import SwiftUI

struct GoalSheetView: View {
    let sheet: GoalSheet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch sheet {
                case .new: GoalEditorView(goalId: nil)
                case .edit(let id): GoalEditorView(goalId: id)
                case .all: GoalsManageView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(GoalsConstants.close) { dismiss() }
                }
            }
        }
    }
}
