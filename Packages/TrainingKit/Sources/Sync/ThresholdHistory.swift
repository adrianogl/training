import FITReader
import Foundation
import Metrics
import Storage
import SwiftData
import TrainingCore

public func thresholdHeartRate(on day: Day, in context: ModelContext) throws -> Int? {
    try ThresholdTimeline(in: context).heartRate(on: day)
}

public func thresholdHeartRates(on days: some Sequence<Day>, in context: ModelContext) throws -> [Day: Int] {
    let timeline = try ThresholdTimeline(in: context)
    return days.reduce(into: [:]) { result, day in
        result[day] = timeline.heartRate(on: day)
    }
}

public func runningZonesSport(in context: ModelContext) throws -> String? {
    let sports = try context.fetch(FetchDescriptor<HeartRateZonesRecord>()).map(\.sport)
    if sports.contains(SyncConstants.runningZonesSport) { return SyncConstants.runningZonesSport }
    return sports.count == 1 ? sports.first : nil
}

public func runningZonesRecord(in context: ModelContext) throws -> HeartRateZonesRecord? {
    guard let sport = try runningZonesSport(in: context) else { return nil }
    var descriptor = FetchDescriptor<HeartRateZonesRecord>(predicate: #Predicate { $0.sport == sport })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

func recordFITThreshold(for record: ActivityRecord, in context: ModelContext) throws {
    let day = activityDay(record)
    let iso = day.iso
    let sameDay = try context.fetch(FetchDescriptor<ActivityRecord>(
        predicate: #Predicate { $0.localDay == iso && $0.fitThresholdHeartRate != nil }
    ))
    let latest = (sameDay + [record])
        .filter { ActivityTypeKey.isRun($0.typeKey) && $0.fitThresholdHeartRate != nil && activityDay($0) == day }
        .max { $0.start < $1.start }
    guard let heartRate = latest?.fitThresholdHeartRate else { return }
    let sport = SyncConstants.fitThresholdSport
    var descriptor = FetchDescriptor<ThresholdHistoryRecord>(predicate: #Predicate { $0.sport == sport && $0.day == iso })
    descriptor.fetchLimit = 1
    if let existing = try context.fetch(descriptor).first {
        existing.heartRate = heartRate
    } else {
        context.insert(ThresholdHistoryRecord(sport: sport, day: iso, heartRate: heartRate))
    }
}

func activityDay(_ record: ActivityRecord) -> Day {
    record.localDay.flatMap(Day.init(iso:)) ?? ActivityTime.day(of: record.start)
}

func assignThresholdZones(to record: ActivityRecord, samples: [FITSample], threshold: Int?) {
    record.thresholdUsed = threshold
    record.thresholdZoneSeconds = threshold.flatMap { zoneSeconds(samples, zones: thresholdZones(thresholdHeartRate: $0)) } ?? []
}

@discardableResult
public func refreshThresholdZoneSeconds(in context: ModelContext, limit: Int? = nil, changed activityIds: Set<Int64> = []) throws -> Int {
    try invalidateOutdatedThresholdZones(in: context)
    try refreshThresholdEstimates(in: context, changed: activityIds, limit: limit)
    let timeline = try ThresholdTimeline(in: context)
    let descriptor = FetchDescriptor<ActivityRecord>(
        predicate: #Predicate { $0.fitProcessed },
        sortBy: [SortDescriptor(\.start, order: .reverse)]
    )
    var refreshed = 0
    for record in try context.fetch(descriptor) where ActivityTypeKey.isRun(record.typeKey) {
        if let limit, refreshed >= limit { break }
        let threshold = timeline.heartRate(on: activityDay(record))
        guard record.thresholdUsed != threshold, let data = record.samplesData,
              let samples = FITSampleCoding.decode(data) else { continue }
        assignThresholdZones(to: record, samples: samples, threshold: threshold)
        refreshed += 1
    }
    if refreshed > 0 { try context.save() }
    return refreshed
}

func invalidateOutdatedThresholdZones(in context: ModelContext) throws {
    let sport = SyncConstants.thresholdZonesVersionSport
    var marker = FetchDescriptor<ThresholdHistoryRecord>(predicate: #Predicate { $0.sport == sport })
    marker.fetchLimit = 1
    let stored = try context.fetch(marker).first
    guard (stored?.heartRate ?? 0) < SyncConstants.thresholdZonesVersion else { return }
    let runs = try context.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.fitProcessed && $0.thresholdUsed != nil }))
    for record in runs { record.thresholdUsed = nil }
    try deleteThresholdEstimates(in: context)
    if let stored {
        stored.heartRate = SyncConstants.thresholdZonesVersion
    } else {
        context.insert(ThresholdHistoryRecord(sport: sport, day: "", heartRate: SyncConstants.thresholdZonesVersion))
    }
    try context.save()
}

extension SyncEngine {
    func applyThresholdZones(to record: ActivityRecord, samples: [FITSample]) throws {
        let threshold = try ThresholdTimeline(in: modelContext).heartRate(on: activityDay(record))
        assignThresholdZones(to: record, samples: samples, threshold: threshold)
    }
}
