import SwiftUI

struct StrengthFrequencyBars: View {
    let counts: [Int]

    var body: some View {
        let top = max(counts.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                RoundedRectangle(cornerRadius: 2)
                    .fill(BrandColors.accentFill.opacity(index == counts.count - 1 ? 1 : 0.5))
                    .frame(height: max(2, StrengthConstants.freqHeight * CGFloat(count) / CGFloat(top)))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: StrengthConstants.freqHeight, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
