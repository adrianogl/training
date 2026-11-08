import Foundation
import TrainingCore

public protocol GarminDataSource: Sendable {
    func heartRateZones() async throws -> HRZonesDTO
    func dailySummaries(from: Day, to: Day) async throws -> [DailySummaryDTO]
    func hrvSummaries(from: Day, to: Day) async throws -> [HRVSummaryDTO]
    func sleepSummaries(from: Day, to: Day) async throws -> [SleepDTO]
    func bodyBattery(from: Day, to: Day) async throws -> [BodyBatteryDayDTO]
    func activities(start: Int, limit: Int, from: Day?, to: Day?) async throws -> [ActivityDTO]
    func fitArchive(activityId: Int64) async throws -> Data
}
