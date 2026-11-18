import SwiftUI

struct NewBadge: View {
    var body: some View {
        DSChip(text: WorkoutConstants.newBadge, tone: .accent, style: .solid)
    }
}
