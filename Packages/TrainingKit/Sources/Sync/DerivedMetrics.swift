import Foundation
import Metrics
import Storage
import SwiftData
import TrainingCore

extension SyncEngine {
    func loadAffectedDays(_ activityIds: Set<Int64>) throws -> Set<Day> {
        guard !activityIds.isEmpty else { return [] }
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { activityIds.contains($0.activityId) })
        let current = today()
        var days: Set<Day> = []
        for record in try modelContext.fetch(descriptor) {
            guard let day = record.localDay.flatMap(Day.init(iso:)), day <= current else { continue }
            for offset in 1...SyncConstants.chronicLoadDays {
                let affected = day.adding(days: offset)
                guard affected <= current else { break }
                days.insert(affected)
            }
        }
        return days
    }

    func updateReadiness(days: Set<Day>) throws {
        guard let earliest = days.min(), let latest = days.max() else { return }
        let dailyLoad = try dailyLoad(from: earliest.adding(days: -SyncConstants.chronicLoadDays), to: latest.adding(days: -1))
        let keys = Set(days.map(\.iso))
        let records = try modelContext.fetch(FetchDescriptor<DailyRecord>(predicate: #Predicate { keys.contains($0.day) }))
        for record in records {
            guard let day = Day(iso: record.day) else { continue }
            let result = readiness(readinessInput(for: record, acuteChronic: acuteChronicRatio(dailyLoad: dailyLoad, on: day.adding(days: -1))))
            record.readinessScore = result?.score
            record.readinessPartial = result?.partial ?? false
        }
        try modelContext.save()
    }

    private func readinessInput(for record: DailyRecord, acuteChronic: Double?) -> ReadinessInput {
        var baseline: HRVBaseline?
        if let lowUpper = record.hrvLowUpper, let balancedLow = record.hrvBalancedLow, let balancedUpper = record.hrvBalancedUpper {
            baseline = HRVBaseline(lowUpper: lowUpper, balancedLow: balancedLow, balancedUpper: balancedUpper)
        }
        return ReadinessInput(
            hrvLastNight: record.hrvLastNight,
            hrvBaseline: baseline,
            sleepScore: record.sleepScore.map(Double.init),
            bodyBatteryMorningMax: record.bodyBatteryMorningMax.map(Double.init),
            acuteChronic: acuteChronic
        )
    }

    private func dailyLoad(from: Day, to: Day) throws -> [Day: Double] {
        let lower = ActivityTime.startOfDay(from)
        let upper = ActivityTime.startOfDay(to.adding(days: 1))
        var descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= lower && $0.start < upper })
        descriptor.propertiesToFetch = [\.start, \.activityTrainingLoad]
        var load: [Day: Double] = [:]
        for activity in try modelContext.fetch(descriptor) where activity.hasStart {
            guard let value = activity.activityTrainingLoad else { continue }
            load[ActivityTime.day(of: activity.start), default: 0] += value
        }
        return load
    }
}
