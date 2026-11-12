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

func recordFITThreshold(_ heartRate: Int, on day: Day, in context: ModelContext) throws {
    let sport = SyncConstants.fitThresholdSport
    let iso = day.iso
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
func refreshThresholdZoneSeconds(in context: ModelContext, limit: Int? = nil) throws -> Int {
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
              let samples = try? JSONDecoder().decode([FITSample].self, from: data) else { continue }
        assignThresholdZones(to: record, samples: samples, threshold: threshold)
        refreshed += 1
    }
    if refreshed > 0 { try context.save() }
    return refreshed
}

extension SyncEngine {
    func applyThresholdZones(to record: ActivityRecord, samples: [FITSample]) throws {
        let threshold = try ThresholdTimeline(in: modelContext).heartRate(on: activityDay(record))
        assignThresholdZones(to: record, samples: samples, threshold: threshold)
    }
}
