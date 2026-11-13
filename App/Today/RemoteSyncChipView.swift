import SwiftUI

struct RemoteSyncChipView: View {
    let chip: RemoteSyncChip
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(chip.text)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var color: Color {
        switch chip {
        case .waiting: BrandColors.attention
        case .failed: BrandColors.danger
        }
    }
}
