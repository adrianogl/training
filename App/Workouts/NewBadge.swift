import SwiftUI

struct NewBadge: View {
    var body: some View {
        Text(WorkoutConstants.newBadge)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(BrandColors.onAccent)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(BrandColors.accentFill, in: Capsule())
    }
}
