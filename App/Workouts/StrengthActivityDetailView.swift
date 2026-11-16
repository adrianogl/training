import SwiftUI

struct StrengthActivityDetailView: View {
    @Environment(AppModel.self) private var app
    let activityId: Int64
    @State private var model = StrengthModel()

    var body: some View {
        StrengthSessionView(model: model, sessionId: activityId)
            .task(id: activityId) {
                await model.load(container: app.container, client: app.mfitAccount.client, plan: app.trainer.plan)
            }
    }
}
