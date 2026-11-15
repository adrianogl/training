import SwiftUI

extension View {
    @ViewBuilder
    func brandCard(framed: Bool, fillsHeight: Bool = false) -> some View {
        if framed {
            brandCard(fillsHeight: fillsHeight)
        } else {
            frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
