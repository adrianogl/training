import SwiftUI

struct PlannedBadge: View {
    var body: some View {
        DSChip(text: WorkoutConstants.plannedBadge, tone: .neutral).fixedSize()
    }
}
