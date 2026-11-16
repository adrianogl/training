import SwiftUI

struct StrengthChip: View {
    let text: String
    var detail: String?
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(text).font(.caption.weight(.semibold))
            if let detail {
                Text(detail).font(BrandFonts.number(12)).opacity(0.75)
            }
        }
        .lineLimit(1)
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
