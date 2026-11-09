import FITReader
import Foundation
import Metrics
import Storage
import SwiftData
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

func runningZones(_ context: ModelContext) throws -> HeartRateZonesRecord? {
    let records = try context.fetch(FetchDescriptor<HeartRateZonesRecord>())
    return records.first { $0.sport == InsightsConstants.zonesSport } ?? (records.count == 1 ? records.first : nil)
}

func zone2Range(_ zones: HeartRateZonesRecord?) -> ClosedRange<Int>? {
    guard let floor = zones?.zone2Floor, let next = zones?.zone3Floor, next - 1 >= floor else { return nil }
    return floor...(next - 1)
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
