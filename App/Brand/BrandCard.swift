import SwiftUI

struct BrandCard: ViewModifier {
    var fillsHeight = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
        content
            .padding(BrandConstants.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
            .background(BrandColors.card, in: shape)
            .overlay(shape.strokeBorder(BrandColors.cardBorder, lineWidth: 1))
    }
}

extension View {
    func brandCard(fillsHeight: Bool = false) -> some View {
        modifier(BrandCard(fillsHeight: fillsHeight))
    }
}
