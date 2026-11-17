import SwiftUI

struct ClaudeSourceChip: View {
    var body: some View {
        Text(ClaudeText.source)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(ClaudeConstants.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(ClaudeConstants.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
