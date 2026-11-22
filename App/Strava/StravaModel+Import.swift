import Foundation
import RemoteSync
import Storage
import SwiftData
import TrainingCore

extension StravaModel {
    func runCandidates(now: Date = .now) async throws -> [StravaRunCandidate] {
        guard let client = link?() else { throw StravaLinkError.notConnected }
        let after = now.addingTimeInterval(-Double(StravaRunMatchingConstants.backfillDays) * StravaConstants.secondsPerDay)
        let runs = try await client.runs(after: after, before: now)
        return StravaRunMatching.unmatched(runs, existing: existingRuns(since: after.addingTimeInterval(-StravaRunMatchingConstants.window)))
            .sorted { $0.start > $1.start }
    }

    private func existingRuns(since start: Date) -> [(start: Date, meters: Double)] {
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= start })
        return ((try? container.mainContext.fetch(descriptor)) ?? [])
            .filter { ActivityTypeKey.isRun($0.typeKey) }
            .map { ($0.start, $0.distance ?? 0) }
    }
}
