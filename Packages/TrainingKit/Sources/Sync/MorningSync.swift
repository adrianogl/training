import Foundation
import GarminAPI
import TrainingCore

extension SyncEngine {
    func performMorning() async throws -> SyncReport {
        var report = SyncReport()
        let today = today()
        let state = try syncState()
        guard state.firstLoadCompleted else { return report }
        do {
            let touched = try await syncDaily(
                starts: DailyStarts(all: today.adding(days: -SyncConstants.morningDaysBack)), to: today, state: state, tracksResume: false
            ) { _ in }
            report.dailyUpserted = touched.count
            try modelContext.save()
        } catch GarminAPIError.rateLimited(_) {
            report.stoppedByRateLimit = true
        }
        return report
    }
}
