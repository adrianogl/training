import Foundation
import Storage
import SwiftData
import Sync
import TrainingCore
import WorkoutAnalysis

enum ScoreStore {
    static func key(
        record: ActivityRecord,
        previous: [ActivityRecord],
        thresholdByDay: [Day: Int],
        watchZones: HeartRateZones?,
        version: Int = AnalysisConstants.scoreVersion
    ) -> String {
        let zones = { (run: ActivityRecord) in zoneSource(run, thresholdByDay: thresholdByDay, watchZones: watchZones) }
        return [
            String(version),
            zones(record),
            String(record.processingVersion),
            previous.map { [String($0.activityId), zones($0), String($0.processingVersion)].joined(separator: WorkoutConstants.scoreKeyFieldSeparator) }
                .joined(separator: WorkoutConstants.scoreKeyIdSeparator),
        ].joined(separator: WorkoutConstants.scoreKeySeparator)
    }

    private static func zoneSource(_ record: ActivityRecord, thresholdByDay: [Day: Int], watchZones: HeartRateZones?) -> String {
        if let threshold = thresholdByDay[WorkoutAnalysisContext.day(record)] { return String(threshold) }
        return WorkoutAnalysisContext.watchZones(for: record, fallback: watchZones)?.floors
            .map(String.init)
            .joined(separator: WorkoutConstants.scoreKeyFloorSeparator) ?? WorkoutConstants.scoreKeyMissing
    }

    static func refresh(container: ModelContainer, ids: [Int64]?) async {
        await Task.detached(priority: .utility) {
            update(in: ModelContext(container), ids: ids)
        }.value
    }

    static func update(in context: ModelContext, ids: [Int64]?) {
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        let wanted = ids.map(Set.init)
        let runs = records.filter { ActivityTypeKey.isRun($0.typeKey) }
        let runStarts = runs.map(\.start)
        let named = Dictionary(grouping: records.filter { $0.workoutName != nil }) { $0.workoutName ?? "" }
        let watchZones = (try? runningZonesRecord(in: context)).flatMap(WorkoutAnalysisContext.zones(from:))
        let thresholdByDay = (try? thresholdHeartRates(on: runs.map(WorkoutAnalysisContext.day), in: context)) ?? [:]
        var inputs: WorkoutAnalysisInputs?
        var changed = false
        for record in runs where wanted?.contains(record.activityId) != false {
            let pool = record.workoutName.flatMap { named[$0] } ?? window(before: record, runs: runs, starts: runStarts)
            let key = key(
                record: record,
                previous: WorkoutAnalysisContext.comparisonCandidates(of: record, in: pool),
                thresholdByDay: thresholdByDay,
                watchZones: watchZones
            )
            guard record.scoreKey != key else { continue }
            let resolved = inputs ?? WorkoutAnalysisContext.inputs(records: records, in: context)
            inputs = resolved
            let score = WorkoutAnalysisContext.score(record: record, records: records, inputs: resolved)
            record.scoreValue = score?.value
            record.scoreData = score.flatMap { try? JSONEncoder().encode($0) }
            record.scoreKey = key
            changed = true
        }
        if changed { try? context.save() }
    }

    private static func window(before record: ActivityRecord, runs: [ActivityRecord], starts: [Date]) -> [ActivityRecord] {
        let windowStart = record.start.addingTimeInterval(-WorkoutDetailConstants.similarRunWindowDays * WorkoutDetailConstants.secondsPerDay)
        let upper = firstIndex(in: starts) { $0 <= record.start }
        let lower = firstIndex(in: starts) { $0 < windowStart }
        return Array(runs[upper..<max(upper, lower)])
    }

    private static func firstIndex(in descending: [Date], where isPast: (Date) -> Bool) -> Int {
        var low = 0
        var high = descending.count
        while low < high {
            let middle = (low + high) / 2
            if isPast(descending[middle]) { high = middle } else { low = middle + 1 }
        }
        return low
    }
}
