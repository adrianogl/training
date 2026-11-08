import SwiftUI

struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(BrandColors.dim)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .padding(.horizontal, 2)
    }
}
