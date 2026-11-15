import Insights
import SwiftUI

struct TrainerChatSheet: View {
    @Environment(AppModel.self) private var app
    @State private var swap: TrainerChatSwap?
    @State private var request: TrainerRequestPrefill?

    var body: some View {
        if let plan = app.trainer.plan {
            WorkoutChatSheet(
                activityId: TrainerChatConstants.key,
                context: TrainerChatContextBuilder.context(plan: plan, history: app.trainer.history, today: app.trainer.currentDay),
                store: .trainer,
                accessory: { question, answer in AnyView(actions(question: question, answer: answer, plan: plan)) }
            )
            .sheet(item: $swap) { TrainerEditWorkoutView(iso: $0.first.iso, initialSwap: $0.second) }
            .sheet(item: $request) { TrainerRequestView(prefill: $0) }
        }
    }

    private func actions(question: String, answer: ChatMessage, plan: TrainerPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(TrainerChatActions.detect(question: question, answer: answer.text, plan: plan, today: app.trainer.currentDay), id: \.self) { action in
                switch action {
                case .swap(let value):
                    Button(TrainerChatActions.label(for: value)) { swap = value }.buttonStyle(TrainerSecondaryButtonStyle())
                case .request(let value):
                    Button(TrainerChatConstants.requestLabel) { request = value }.buttonStyle(TrainerSecondaryButtonStyle())
                }
            }
        }
    }
}
