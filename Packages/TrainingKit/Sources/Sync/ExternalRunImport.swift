import FITReader
import Foundation
import GarminAPI
import Storage
import SwiftData
import TrainingCore

extension SyncEngine {
    @discardableResult
    public func importExternalRuns(_ dtos: [ActivityDTO]) async throws -> Set<Int64> {
        guard !dtos.isEmpty else { return [] }
        for dto in dtos { try upsertActivity(dto) }
        try modelContext.save()
        try backfillLocalDays()
        let ids = Set(dtos.map(\.activityId))
        let records = try modelContext.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { ids.contains($0.activityId) }))
        let result = try await processFITQueue(records) { _ in }
        try updateReadiness(days: try loadAffectedDays(ids))
        try modelContext.save()
        return result.activityIds
    }

    public func removeActivities(_ ids: Set<Int64>) throws {
        guard !ids.isEmpty else { return }
        let days = try loadAffectedDays(ids)
        for record in try modelContext.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { ids.contains($0.activityId) })) {
            modelContext.delete(record)
        }
        try modelContext.save()
        try updateReadiness(days: days)
        try modelContext.save()
    }

    func removeStravaTwins() throws -> Int {
        let low = StravaActivityId.lowerBound
        let high = StravaActivityId.upperBound
        let strava = try modelContext.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId >= low && $0.activityId <= high }))
        var twins: Set<Int64> = []
        for run in strava {
            let from = run.start.addingTimeInterval(-SyncConstants.externalMatchWindow)
            let to = run.start.addingTimeInterval(SyncConstants.externalMatchWindow)
            let near = try modelContext.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= from && $0.start <= to }))
            if near.contains(where: { !StravaActivityId.isStrava($0.activityId) && ActivityTypeKey.isRun($0.typeKey) && ExternalRunMatch.matches(run, $0) }) {
                twins.insert(run.activityId)
            }
        }
        try removeActivities(twins)
        return twins.count
    }
}

public enum ExternalRunMatch {
    public static func matches(start: Date, meters: Double, otherStart: Date, otherMeters: Double) -> Bool {
        abs(start.timeIntervalSince(otherStart)) <= SyncConstants.externalMatchWindow
            && abs(meters - otherMeters) <= max(meters, otherMeters) * SyncConstants.externalDistanceTolerance
    }

    static func matches(_ a: ActivityRecord, _ b: ActivityRecord) -> Bool {
        matches(start: a.start, meters: a.distance ?? 0, otherStart: b.start, otherMeters: b.distance ?? 0)
    }
}
