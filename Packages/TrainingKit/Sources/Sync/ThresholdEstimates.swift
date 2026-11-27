import FITReader
import Foundation
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

public func estimatedMaxHeartRate(on day: Day, in context: ModelContext) throws -> Int? {
    let sport = SyncConstants.maxHeartRateSport
    let upper = day.iso
    let lower = day.adding(days: -SyncConstants.maxHeartRateWindowDays).iso
    let records = try context.fetch(FetchDescriptor<ThresholdHistoryRecord>(
        predicate: #Predicate { $0.sport == sport && $0.day > lower && $0.day <= upper && $0.heartRate > 0 }
    ))
    return records.map(\.heartRate).max()
}

@discardableResult
func refreshThresholdEstimates(in context: ModelContext, changed activityIds: Set<Int64> = [], limit: Int? = nil) throws -> Int {
    let runs = try context.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.fitProcessed }))
        .filter { ActivityTypeKey.isRun($0.typeKey) }
    let maxSport = SyncConstants.maxHeartRateSport
    let estimateSport = SyncConstants.thresholdEstimateSport
    var stored: [ThresholdHistoryRecord] = []
    var duplicates = 0
    var seen: Set<String> = []
    for record in try context.fetch(FetchDescriptor<ThresholdHistoryRecord>(
        predicate: #Predicate { $0.sport == maxSport || $0.sport == estimateSport }
    )) {
        if seen.insert("\(record.sport)|\(record.day)").inserted {
            stored.append(record)
        } else {
            context.delete(record)
            duplicates += 1
        }
    }
    var records = Dictionary(grouping: stored) { $0.day }
    let byDay = Dictionary(grouping: runs) { activityDay($0).iso }
    var refreshed = 0
    for record in stored where byDay[record.day] == nil {
        context.delete(record)
        refreshed += 1
    }
    let hotSessions = ActivityRecord.hotSessionCounts(runs)
    let raceKms = try context.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.deletedAt == nil })).map { $0.distance / 1_000 }
    for (day, dayRuns) in byDay.sorted(by: { $0.key > $1.key }) {
        let evaluated = records[day]?.contains { $0.sport == maxSport } == true
        let hotEstimate = records[day]?.contains { $0.sport == estimateSport } == true && dayRuns.contains { run in
            discardsThresholdEstimate(heatFactor: heatFactor(run, hotSessions: hotSessions))
                && classifyRun(run, longGoalKm: nil, raceGoalKms: raceKms) == .tempo
        }
        guard !evaluated || hotEstimate || dayRuns.contains(where: { activityIds.contains($0.activityId) }) else { continue }
        if let limit, refreshed >= limit { break }
        let decoded = dayRuns.sorted { $0.start > $1.start }.map { ($0, $0.samplesData.flatMap(FITSampleCoding.decode) ?? []) }
        let maximum = decoded.compactMap { sustainedMaxHeartRate($0.1) }.max() ?? 0
        let estimate = decoded.lazy.compactMap { run, samples in
            estimateThresholdHeartRate(run, samples: samples, heatFactor: heatFactor(run, hotSessions: hotSessions), raceGoalKms: raceKms)
        }.first
        var existing = records[day] ?? []
        upsert(sport: maxSport, day: day, heartRate: maximum, existing: &existing, in: context)
        if let estimate {
            upsert(sport: estimateSport, day: day, heartRate: estimate, existing: &existing, in: context)
        } else if let index = existing.firstIndex(where: { $0.sport == estimateSport }) {
            context.delete(existing.remove(at: index))
        }
        records[day] = existing
        refreshed += 1
    }
    if refreshed + duplicates > 0 { try context.save() }
    return refreshed
}

func deleteThresholdEstimates(in context: ModelContext) throws {
    let maxSport = SyncConstants.maxHeartRateSport
    let estimateSport = SyncConstants.thresholdEstimateSport
    try context.fetch(FetchDescriptor<ThresholdHistoryRecord>(
        predicate: #Predicate { $0.sport == maxSport || $0.sport == estimateSport }
    )).forEach(context.delete)
}

private func heatFactor(_ run: ActivityRecord, hotSessions: [Int64: Int]) -> Double? {
    let effect = run.weatherEffect(hotSessions: hotSessions)
    return effect?.isHeat == true ? effect?.paceFactor : nil
}

private func upsert(sport: String, day: String, heartRate: Int, existing: inout [ThresholdHistoryRecord], in context: ModelContext) {
    if let record = existing.first(where: { $0.sport == sport }) {
        if record.heartRate != heartRate { record.heartRate = heartRate }
    } else {
        let record = ThresholdHistoryRecord(sport: sport, day: day, heartRate: heartRate)
        context.insert(record)
        existing.append(record)
    }
}
