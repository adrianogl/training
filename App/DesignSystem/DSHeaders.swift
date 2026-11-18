import SwiftUI

struct DSSectionTitle: View {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct DSCardLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(BrandColors.dim)
            .accessibilityAddTraits(.isHeader)
    }
}
