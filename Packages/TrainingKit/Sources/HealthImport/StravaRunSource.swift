import FITReader
import Foundation
import GarminAPI
import Sync
import TrainingCore

public struct StravaRunSource: GarminDataSource, ActivityDetailSource {
    let summaries: [Int64: FITSummary]

    public init(summaries: [Int64: FITSummary]) {
        self.summaries = summaries
    }

    public func activitySummary(activityId: Int64) async throws -> FITSummary? { summaries[activityId] }
    public func heartRateZones() async throws -> HRZonesDTO { throw GarminAPIError.notAcceptable }
    public func dailySummaries(from: Day, to: Day) async throws -> [DailySummaryDTO] { [] }
    public func hrvSummaries(from: Day, to: Day) async throws -> [HRVSummaryDTO] { [] }
    public func sleepSummaries(from: Day, to: Day) async throws -> [SleepDTO] { [] }
    public func bodyBattery(from: Day, to: Day) async throws -> [BodyBatteryDayDTO] { [] }
    public func activities(start: Int, limit: Int, from: Day?, to: Day?) async throws -> [ActivityDTO] { [] }
    public func fitArchive(activityId: Int64) async throws -> Data { throw GarminAPIError.notAcceptable }
}
