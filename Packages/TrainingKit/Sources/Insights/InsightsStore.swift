import FITReader
import Foundation
import Metrics
import Storage
import SwiftData
import Sync
import TrainingCore

func activityDay(_ activity: ActivityRecord) -> Day {
    Day.today(in: .current, now: activity.start)
}

func isRun(_ activity: ActivityRecord) -> Bool {
    activity.hasStart && ActivityTypeKey.isRun(activity.typeKey)
}

func startOfDay(_ day: Day) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .distantPast
}

func fetchActivities(_ context: ModelContext, since day: Day?, through today: Day) throws -> [ActivityRecord] {
    let upper = startOfDay(today.adding(days: 1))
    var descriptor: FetchDescriptor<ActivityRecord>
    if let day {
        let lower = startOfDay(day)
        descriptor = FetchDescriptor(predicate: #Predicate { $0.start >= lower && $0.start < upper })
    } else {
        descriptor = FetchDescriptor(predicate: #Predicate { $0.start < upper })
    }
    descriptor.sortBy = [SortDescriptor(\.start)]
    return try context.fetch(descriptor).filter(\.hasStart)
}

func fetchDaily(_ context: ModelContext, since day: Day?, through today: Day) throws -> [(Day, DailyRecord)] {
    let upper = today.iso
    var descriptor: FetchDescriptor<DailyRecord>
    if let day {
        let lower = day.iso
        descriptor = FetchDescriptor(predicate: #Predicate { $0.day >= lower && $0.day <= upper })
    } else {
        descriptor = FetchDescriptor(predicate: #Predicate { $0.day <= upper })
    }
    descriptor.sortBy = [SortDescriptor(\.day)]
    return try context.fetch(descriptor).compactMap { record in Day(iso: record.day).map { ($0, record) } }
}

func watchZonesRecord(_ context: ModelContext) throws -> HeartRateZonesRecord? {
    let records = try context.fetch(FetchDescriptor<HeartRateZonesRecord>())
    return records.first { $0.sport == InsightsConstants.zonesSport } ?? (records.count == 1 ? records.first : nil)
}

func runningZones(on day: Day, _ context: ModelContext) throws -> HeartRateZones? {
    let record = try watchZonesRecord(context)
    let sport = record?.sport ?? InsightsConstants.zonesSport
    if let threshold = try thresholdHeartRate(on: day, sport: sport, in: context) {
        return thresholdZones(thresholdHeartRate: threshold)
    }
    let floors = [record?.zone1Floor, record?.zone2Floor, record?.zone3Floor, record?.zone4Floor, record?.zone5Floor].compactMap { $0 }
    return floors.count == InsightsConstants.zoneCount ? HeartRateZones(floors: floors, maxHeartRate: record?.maxHeartRate) : nil
}

func hasThreshold(_ context: ModelContext, today: Day) throws -> Bool {
    let sport = try watchZonesRecord(context)?.sport ?? InsightsConstants.zonesSport
    return try thresholdHeartRate(on: today, sport: sport, in: context) != nil
}

func zone2Range(_ zones: HeartRateZones?) -> ClosedRange<Int>? {
    guard let floors = zones?.floors, floors.count > 2, floors[2] - 1 >= floors[1] else { return nil }
    return floors[1]...(floors[2] - 1)
}

func focusZoneSeconds(_ activity: ActivityRecord, thresholdAvailable: Bool) -> [Double] {
    thresholdAvailable && isRun(activity) ? activity.thresholdZoneSeconds : activity.zoneSeconds
}

func samples(of activity: ActivityRecord) -> [FITSample]? {
    guard let data = activity.samplesData else { return nil }
    return try? JSONDecoder().decode([FITSample].self, from: data)
}

func dailyMeans(_ values: [(Day, Double)]) -> [(Day, Double)] {
    var sums: [Day: (total: Double, count: Int)] = [:]
    for (day, value) in values where value.isFinite {
        let current = sums[day] ?? (0, 0)
        sums[day] = (current.total + value, current.count + 1)
    }
    return sums.map { ($0.key, $0.value.total / Double($0.value.count)) }.sorted { $0.0 < $1.0 }
}

func average(_ values: [Double]) -> Double? {
    values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
}

func distanceLabel(_ meters: Double) -> String {
    if let label = InsightsConstants.distanceLabels[meters] { return label }
    let km = meters / InsightsConstants.metersPerKm
    let text = km.rounded() == km ? String(format: "%.0f", km) : String(format: "%.1f", km)
    return text.replacingOccurrences(of: ".", with: ",") + InsightsConstants.kmSuffix
}

func chunkedPredictionSeries(distance: Double, efforts: [Effort], from: Day, to: Day) -> [(Day, Double)] {
    typealias C = InsightsConstants
    var series: [(Day, Double)] = []
    var chunkStart = from
    while chunkStart <= to {
        let chunkEnd = min(chunkStart.adding(days: C.predictionChunkDays - 1), to)
        let earliest = chunkStart.adding(days: -C.effortWindowDays)
        let relevant = efforts.filter { $0.day >= earliest && $0.day <= chunkEnd }
        if !relevant.isEmpty {
            series += predictionSeries(distance: distance, efforts: relevant, from: chunkStart, to: chunkEnd)
        }
        chunkStart = chunkEnd.adding(days: 1)
    }
    return series
}
