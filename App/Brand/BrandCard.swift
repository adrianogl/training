import SwiftUI

struct BrandCard: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
        content
            .padding(BrandConstants.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrandColors.card, in: shape)
            .overlay(shape.strokeBorder(BrandColors.cardBorder, lineWidth: 1))
    }
}

extension View {
    func brandCard() -> some View {
        modifier(BrandCard())
    }
}
