import SwiftUI

struct AskIntelligenceButton: View {
    let title: String
    var secondary = false
    let action: () -> Void

    var body: some View {
        if WorkoutChatEngine.isAvailable {
            Button(action: action) {
                if secondary {
                    Label(title, systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BrandColors.line, lineWidth: 1))
                } else {
                    Label(title, systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BrandColors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BrandColors.accentFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        } else {
            Label(WorkoutChatConstants.unavailable, systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
        }
    }
}
