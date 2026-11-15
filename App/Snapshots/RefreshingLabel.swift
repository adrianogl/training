import SwiftUI

struct RefreshingLabel: View {
    var body: some View {
        HStack(spacing: ScreenSnapshotConstants.refreshingSpacing) {
            ProgressView().controlSize(.mini)
            Text(ScreenSnapshotConstants.refreshingLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, ScreenSnapshotConstants.refreshingBottomPadding)
        .accessibilityElement(children: .combine)
    }
}
