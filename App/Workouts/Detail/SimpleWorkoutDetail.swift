import SwiftUI

struct SimpleWorkoutDetail: View {
    let summary: WorkoutSummary
    let zoneShares: [ZoneShare]

    var body: some View {
        SummaryHeader(summary: summary)
        if !zoneShares.isEmpty {
            DSCardLabel("Tempo em zona de FC").padding(.top, DSSpacing.sectionTop).padding(.bottom, DSSpacing.sectionBottom)
                .id(WorkoutDetailSection.zones)
            ZonesBar(shares: zoneShares)
        }
    }
}
