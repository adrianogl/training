import SwiftUI

struct StrengthActivityDetailView: View {
    @Environment(AppModel.self) private var app
    let activityId: Int64
    @State private var model = StrengthModel()
    @State private var confirmsDelete = false

    var body: some View {
        StrengthSessionView(model: model, sessionId: activityId)
            .task(id: activityId) {
                await model.load(container: app.container, client: app.mfitAccount.client, plan: app.trainer.plan)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ActivityDeleteButton(isPresented: $confirmsDelete)
                    } label: {
                        Image(systemName: WorkoutDetailConstants.actionsSymbol)
                    }
                    .accessibilityLabel(WorkoutDetailConstants.actionsTitle)
                }
            }
            .activityDeletion(activityId, isPresented: $confirmsDelete)
    }
}
