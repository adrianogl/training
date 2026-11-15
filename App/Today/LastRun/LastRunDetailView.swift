import SwiftUI

struct LastRunDetailView: View {
    let lastRun: LastRunSummary
    var plannedKm: Double?

    var body: some View {
        ScrollView {
            LastRunCard(lastRun: lastRun, plannedKm: plannedKm)
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
        }
        .background(BrandBackground())
        .navigationTitle(TodayConstants.lastRunTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
