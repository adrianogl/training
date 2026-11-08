import SwiftUI

struct SimpleWorkoutDetail: View {
    let summary: WorkoutSummary
    let zoneShares: [ZoneShare]

    var body: some View {
        SummaryHeader(summary: summary)
        if !zoneShares.isEmpty {
            SectionLabel("Tempo em zona de FC")
                .id(WorkoutDetailSection.zones)
            ZonesBar(shares: zoneShares)
        }
    }
}
