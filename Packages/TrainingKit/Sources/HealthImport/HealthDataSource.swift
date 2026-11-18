import FITReader
import Foundation
import GarminAPI
import Sync
import TrainingCore

public enum HealthSourceError: Error, Equatable {
    case noFITArchive
}

public actor HealthDataSource: GarminDataSource, ActivityDetailSource {
    private typealias C = HealthImportConstants

    private let reader: any HealthReading
    private let now: @Sendable () -> Date
    private var cache: [Int64: HealthWorkout] = [:]
    private var bounds: (resting: Double, maximum: Double)?

    public init(reader: any HealthReading, now: @escaping @Sendable () -> Date = { .now }) {
        self.reader = reader
        self.now = now
    }

    public func heartRateZones() async throws -> HRZonesDTO {
        let limits = try await heartRateBounds()
        return HealthMapping.zones(maximum: limits.maximum, resting: limits.resting)
    }

    public func dailySummaries(from: Day, to: Day) async throws -> [DailySummaryDTO] {
        try await reader.restingHeartRate(from: from, to: to)
            .sorted { $0.key < $1.key }
            .map { DailySummaryDTO(day: $0.key, restingHeartRate: Int($0.value.rounded())) }
    }

    public func hrvSummaries(from: Day, to: Day) async throws -> [HRVSummaryDTO] {
        let nights = try await reader.nightlyHRV(from: from.adding(days: -C.hrvBaselineDays), to: to)
        let ordered = nights.sorted { $0.key < $1.key }
        return ordered.filter { $0.key >= from && $0.key <= to }.map { day, value in
            let history = ordered.filter { $0.key < day && $0.key >= day.adding(days: -C.hrvBaselineDays) }.map(\.value)
            let week = ordered.filter { $0.key <= day && $0.key > day.adding(days: -C.hrvWeekDays) }.map(\.value)
            let baseline = HealthMapping.hrvBaseline(history)
            return HRVSummaryDTO(
                day: day,
                lastNightAvg: value,
                weeklyAvg: week.isEmpty ? nil : week.reduce(0, +) / Double(week.count),
                status: baseline.map { HealthMapping.hrvStatus(value, baseline: $0) },
                baselineLowUpper: baseline?.lowUpper,
                baselineBalancedLow: baseline?.balancedLow,
                baselineBalancedUpper: baseline?.balancedUpper
            )
        }
    }

    public func sleepSummaries(from: Day, to: Day) async throws -> [SleepDTO] {
        try await reader.sleep(from: from, to: to).map { HealthMapping.sleep($0) }
    }

    public func bodyBattery(from: Day, to: Day) async throws -> [BodyBatteryDayDTO] {
        []
    }

    public func activities(start: Int, limit: Int, from: Day?, to: Day?) async throws -> [ActivityDTO] {
        let end = to.map { ActivityDay.end(of: $0) } ?? now()
        let begin = from.map { ActivityDay.start(of: $0) } ?? Calendar.current.date(byAdding: .year, value: -C.historyYears, to: now()) ?? .distantPast
        let workouts = try await reader.workouts(from: begin, to: end)
            .filter { $0.kind != .other }
            .sorted { $0.start > $1.start }
        for workout in workouts { cache[HealthMapping.activityId(workout.id)] = workout }
        let limits = try await heartRateBounds()
        guard start < workouts.count else { return [] }
        return workouts[start..<min(start + limit, workouts.count)].map {
            HealthMapping.activity($0, resting: limits.resting, maximum: limits.maximum)
        }
    }

    public func fitArchive(activityId: Int64) async throws -> Data {
        throw HealthSourceError.noFITArchive
    }

    public func activitySummary(activityId: Int64) async throws -> FITSummary? {
        if cache[activityId] == nil { _ = try await activities(start: 0, limit: Int.max / 2, from: nil, to: nil) }
        guard let workout = cache[activityId], workout.kind == .run || workout.kind == .walk else { return nil }
        return HealthMapping.summary(workout, series: try await reader.series(for: workout))
    }

    private func heartRateBounds() async throws -> (resting: Double, maximum: Double) {
        if let bounds { return bounds }
        let today = Day.today(in: .current, now: now())
        let resting = try await reader.restingHeartRate(from: today.adding(days: -C.restingWindowDays), to: today).values.sorted()
        let workouts = try await reader.workouts(from: Calendar.current.date(byAdding: .year, value: -1, to: now()) ?? .distantPast, to: now())
        let maximum = workouts.compactMap(\.maxHeartRate).max() ?? C.fallbackMaxHeartRate
        let result = (resting.isEmpty ? C.fallbackRestingHeartRate : resting[resting.count / 2], maximum)
        bounds = result
        return result
    }
}

enum ActivityDay {
    static func start(of day: Day) -> Date {
        Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .distantPast
    }

    static func end(of day: Day) -> Date {
        start(of: day.adding(days: 1))
    }
}
