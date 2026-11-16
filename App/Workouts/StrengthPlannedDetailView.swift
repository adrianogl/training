import SwiftUI

struct StrengthPlannedDetailView: View {
    @Environment(AppModel.self) private var app
    let workoutId: Int64
    @State private var model = StrengthModel()

    var body: some View {
        StrengthWorkoutView(model: model, workoutId: workoutId)
            .task(id: workoutId) {
                await model.load(container: app.container, client: app.mfitAccount.client, plan: app.trainer.plan)
            }
    }
}
