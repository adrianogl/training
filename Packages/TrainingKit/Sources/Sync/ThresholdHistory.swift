import FITReader
import Foundation
import Metrics
import Storage
import SwiftData
import TrainingCore

public func thresholdHeartRate(on day: Day, sport: String, in context: ModelContext) throws -> Int? {
    try ThresholdTimeline(sport: sport, in: context).heartRate(on: day)
}

public func thresholdHeartRates(on days: some Sequence<Day>, sport: String, in context: ModelContext) throws -> [Day: Int] {
    let timeline = try ThresholdTimeline(sport: sport, in: context)
    return days.reduce(into: [:]) { result, day in
        result[day] = timeline.heartRate(on: day)
    }
}

func recordThreshold(_ heartRate: Int, sport: String, on today: Day, in context: ModelContext) throws {
    var descriptor = FetchDescriptor<ThresholdHistoryRecord>(
        predicate: #Predicate { $0.sport == sport },
        sortBy: [SortDescriptor(\.day, order: .reverse)]
    )
    descriptor.fetchLimit = 1
    let last = try context.fetch(descriptor).first
    guard last?.heartRate != heartRate else { return }
    if let last, last.day == today.iso {
        last.heartRate = heartRate
    } else {
        context.insert(ThresholdHistoryRecord(sport: sport, day: today.iso, heartRate: heartRate))
    }
}

func runningZonesSport(in context: ModelContext) throws -> String? {
    let sports = try context.fetch(FetchDescriptor<HeartRateZonesRecord>()).map(\.sport)
    if sports.contains(SyncConstants.runningZonesSport) { return SyncConstants.runningZonesSport }
    return sports.count == 1 ? sports.first : nil
}

func thresholdTimelineForRuns(in context: ModelContext) throws -> ThresholdTimeline? {
    try runningZonesSport(in: context).map { try ThresholdTimeline(sport: $0, in: context) }
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
    guard let timeline = try thresholdTimelineForRuns(in: context) else { return 0 }
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
        let threshold = try thresholdTimelineForRuns(in: modelContext)?.heartRate(on: activityDay(record))
        assignThresholdZones(to: record, samples: samples, threshold: threshold)
    }
}
