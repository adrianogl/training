import SwiftUI

struct AskIntelligenceButton: View {
    let title: String
    var secondary = false
    let action: () -> Void

    var body: some View {
        if WorkoutChatEngine.isAvailable {
            Button(action: action) {
                Label(title, systemImage: "sparkles")
            }
            .buttonStyle(.ds(secondary ? .secondary : .primary))
        } else {
            Label(WorkoutChatConstants.unavailable, systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
        }
    }
}
