import SwiftUI

struct SectionHeader: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(BrandColors.accent)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .padding(.horizontal, 2)
            .accessibilityAddTraits(.isHeader)
    }
}
