import Foundation
import Insights
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
        version: Int = AnalysisConstants.scoreVersion,
        hotSessions: [Int64: Int] = [:],
        race: RaceTarget? = nil
    ) -> String {
        let zones = { (run: ActivityRecord) in zoneSource(run, thresholdByDay: thresholdByDay, watchZones: watchZones) }
        return [
            versionTag(version),
            zones(record),
            String(record.processingVersion),
            weatherToken(record, hotSessions: hotSessions),
            previous.map { [String($0.activityId), zones($0), String($0.processingVersion), weatherToken($0, hotSessions: hotSessions)].joined(separator: WorkoutConstants.scoreKeyFieldSeparator) }
                .joined(separator: WorkoutConstants.scoreKeyIdSeparator),
        ].joined(separator: WorkoutConstants.scoreKeySeparator) + (race.map { WorkoutConstants.scoreKeySeparator + raceToken($0) } ?? "")
    }

    static func raceToken(_ race: RaceTarget) -> String {
        let paces = race.strategyPaces.sorted { $0.key < $1.key }.map { String(Int(($0.value * WorkoutConstants.scoreKeyWeatherScale).rounded())) }
        return ([String(Int(race.distance.rounded())), race.targetSeconds.map { String(Int(($0 * WorkoutConstants.scoreKeyWeatherScale).rounded())) } ?? WorkoutConstants.scoreKeyMissing] + paces)
            .joined(separator: WorkoutConstants.scoreKeyFloorSeparator)
    }

    static var versionTag: String { versionTag(AnalysisConstants.scoreVersion) }

    static func versionTag(_ version: Int) -> String {
        "\(version).\(WorkoutConstants.analysisStoreVersion)"
    }

    static func weatherToken(_ record: ActivityRecord, hotSessions: [Int64: Int]) -> String {
        guard let effect = record.weatherEffect(hotSessions: hotSessions) else { return WorkoutConstants.scoreKeyMissing }
        let wind = record.weatherWindSpeed.map { String(Int(($0 * WorkoutConstants.scoreKeyWeatherScale).rounded())) } ?? WorkoutConstants.scoreKeyMissing
        return String(Int((effect.paceFactor * WorkoutConstants.scoreKeyWeatherScale).rounded())) + WorkoutConstants.scoreKeyFloorSeparator + wind
    }

    private static func zoneSource(_ record: ActivityRecord, thresholdByDay: [Day: Int], watchZones: HeartRateZones?) -> String {
        if let threshold = thresholdByDay[WorkoutAnalysisContext.day(record)] { return String(threshold) }
        return WorkoutAnalysisContext.watchZones(for: record, fallback: watchZones)?.floors
            .map(String.init)
            .joined(separator: WorkoutConstants.scoreKeyFloorSeparator) ?? WorkoutConstants.scoreKeyMissing
    }

    @discardableResult
    static func refresh(container: ModelContainer, ids: [Int64]?, paceProStore: PaceProStore = PaceProStore()) async -> Bool {
        await Task.detached(priority: .utility) {
            update(in: ModelContext(container), ids: ids, paceProStore: paceProStore)
        }.value
    }

    @discardableResult
    static func update(in context: ModelContext, ids: [Int64]?, paceProStore: PaceProStore = PaceProStore()) -> Bool {
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        let wanted = ids.map(Set.init)
        let runs = records.filter { ActivityTypeKey.isRun($0.typeKey) }
        let runStarts = runs.map(\.start)
        let named = Dictionary(grouping: records.filter { $0.workoutName != nil }) { $0.workoutName.map(WorkoutTitle.comparisonKey) ?? "" }
        let watchZones = (try? runningZonesRecord(in: context)).flatMap(WorkoutAnalysisContext.zones(from:))
        let thresholdByDay = (try? thresholdHeartRates(on: runs.map(WorkoutAnalysisContext.day), in: context)) ?? [:]
        let hotSessions = ActivityRecord.hotSessionCounts(runs)
        let races = WorkoutAnalysisContext.races(in: context, paceProStore: paceProStore)
        var inputs: WorkoutAnalysisInputs?
        var changed = false
        let now = Date.now
        for record in runs where wanted?.contains(record.activityId) != false {
            if ScoreReadiness.pending(record, now: now) != nil {
                if record.scoreKey != nil || record.scoreValue != nil {
                    record.scoreValue = nil
                    record.scoreData = nil
                    record.scoreKey = nil
                    changed = true
                }
                continue
            }
            let race = races.race(for: record)
            let pool = race != nil ? runs
                : record.workoutName.flatMap { named[WorkoutTitle.comparisonKey($0)] } ?? window(before: record, runs: runs, starts: runStarts)
            let key = key(
                record: record,
                previous: WorkoutAnalysisContext.comparisonCandidates(of: record, in: pool, races: races),
                thresholdByDay: thresholdByDay,
                watchZones: watchZones,
                hotSessions: hotSessions,
                race: race
            )
            guard record.scoreKey != key else { continue }
            let resolved = inputs ?? WorkoutAnalysisContext.inputs(records: records, in: context, races: races)
            inputs = resolved
            let analysis = WorkoutAnalysisContext.build(record: record, records: records, inputs: resolved)
            let score = analysis.score
            record.analysisData = WorkoutAnalysisStore.encode(analysis)
            record.scoreValue = score?.value
            record.scoreData = score.flatMap { try? JSONEncoder().encode($0) }
            record.scoreKey = key
            changed = true
        }
        if changed { try? context.save() }
        return changed
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
