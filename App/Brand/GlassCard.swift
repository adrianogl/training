import SwiftUI

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(BrandConstants.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous))
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}
