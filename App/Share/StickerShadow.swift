import SwiftUI

struct StickerShadow: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.shadow(color: BrandColors.stickerShadow, radius: ShareConstants.shadowRadius, y: 1)
        } else {
            content
        }
    }
}
