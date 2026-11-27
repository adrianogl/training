import Foundation
import Storage
import SwiftData
import TrainingCore

struct ThresholdTimeline {
    let estimates: [(day: String, heartRate: Int)]
    let entries: [(day: String, heartRate: Int)]
    let fallback: Int?

    init(in context: ModelContext) throws {
        let estimateSport = SyncConstants.thresholdEstimateSport
        var days: Set<String> = []
        estimates = try context.fetch(FetchDescriptor<ThresholdHistoryRecord>(
            predicate: #Predicate { $0.sport == estimateSport && $0.heartRate > 0 },
            sortBy: [SortDescriptor(\.day)]
        )).filter { days.insert($0.day).inserted }.map { ($0.day, $0.heartRate) }
        let sport = SyncConstants.fitThresholdSport
        let descriptor = FetchDescriptor<ThresholdHistoryRecord>(
            predicate: #Predicate { $0.sport == sport },
            sortBy: [SortDescriptor(\.day)]
        )
        entries = try context.fetch(descriptor).map { ($0.day, $0.heartRate) }
        fallback = try runningZonesRecord(in: context)?.lactateThresholdHeartRate
    }

    func heartRate(on day: Day) -> Int? {
        let iso = day.iso
        if !estimates.isEmpty {
            let last = estimates.lastIndex { $0.day <= iso } ?? estimates.startIndex
            let window = estimates[max(estimates.startIndex, last - SyncConstants.thresholdEstimateRuns + 1)...last]
            return median(window.map(\.heartRate))
        }
        return (entries.last { $0.day <= iso } ?? entries.first)?.heartRate ?? fallback
    }

    private func median(_ values: [Int]) -> Int {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        guard sorted.count.isMultiple(of: 2) else { return sorted[middle] }
        return Int((Double(sorted[middle - 1] + sorted[middle]) / 2).rounded())
    }
}
