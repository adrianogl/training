import SwiftUI

struct DSAIMark: View {
    let text: String

    var body: some View {
        Text(DSAIMarkConstants.symbol + " " + text)
            .font(.caption2)
            .foregroundStyle(BrandColors.dim)
            .accessibilityLabel(text)
    }
}
