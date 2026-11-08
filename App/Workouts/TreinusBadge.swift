import SwiftUI

struct TreinusBadge: View {
    var body: some View {
        Text("Treinus")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(BrandColors.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(BrandColors.accent.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(BrandColors.accent.opacity(0.35), lineWidth: 0.5))
    }
}
