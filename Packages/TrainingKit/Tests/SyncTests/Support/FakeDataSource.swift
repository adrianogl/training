import Foundation
import GarminAPI
import TrainingCore

struct FakeFITError: Error {}

actor FakeDataSource: GarminDataSource {
    nonisolated let dataDays: ClosedRange<Day>?
    nonisolated let activityList: [ActivityDTO]
    private let fitZip: Data?
    private let failure: GarminAPIError?
    private let zonesError: GarminAPIError?
    private let fitErrors: [Int64: GarminAPIError]
    private let cancelledFITs: Set<Int64>
    private let cancelsZones: Bool
    private let dailyDelay: Duration?
    private var sleepFailure: (from: Day, error: GarminAPIError)?
    private var activityFailure: (start: Int, error: GarminAPIError)?

    private(set) var summaryFroms: [Day] = []
    private(set) var hrvFroms: [Day] = []
    private(set) var batteryFroms: [Day] = []
    private(set) var froms: [Day] = []
    private(set) var sleepFroms: [Day] = []
    private(set) var activityPageStarts: [Int] = []
    private(set) var fitCalls: [Int64] = []
    private(set) var zonesCalls = 0

    init(
        dataDays: ClosedRange<Day>?,
        activities: [ActivityDTO] = [],
        fitZip: Data? = nil,
        failure: GarminAPIError? = nil,
        zonesError: GarminAPIError? = nil,
        fitErrors: [Int64: GarminAPIError] = [:],
        cancelledFITs: Set<Int64> = [],
        cancelsZones: Bool = false,
        dailyDelay: Duration? = nil
    ) {
        self.dataDays = dataDays
        self.activityList = activities
        self.fitZip = fitZip
        self.failure = failure
        self.zonesError = zonesError
        self.fitErrors = fitErrors
        self.cancelledFITs = cancelledFITs
        self.cancelsZones = cancelsZones
        self.dailyDelay = dailyDelay
    }

    func failSleep(from: Day?, with error: GarminAPIError = .rateLimited(path: GarminEndpoints.sleepPath)) {
        sleepFailure = from.map { ($0, error) }
    }

    func failActivities(start: Int?, with error: GarminAPIError = .rateLimited(path: GarminEndpoints.activitiesPath)) {
        activityFailure = start.map { ($0, error) }
    }

    nonisolated var dayCount: Int {
        dataDays.map { $0.lowerBound.days(until: $0.upperBound) + 1 } ?? 0
    }

    nonisolated var activityCount: Int { activityList.count }

    func heartRateZones() async throws -> HRZonesDTO {
        zonesCalls += 1
        if cancelsZones { throw CancellationError() }
        if let zonesError { throw zonesError }
        return HRZonesDTO(sport: "DEFAULT", zone1Floor: 100, zone2Floor: 120, zone3Floor: 140, zone4Floor: 160, zone5Floor: 175)
    }

    func dailySummaries(from: Day, to: Day) async throws -> [DailySummaryDTO] {
        froms.append(from)
        summaryFroms.append(from)
        if let dailyDelay { try? await Task.sleep(for: dailyDelay) }
        if let failure { throw failure }
        return days(from: from, to: to).map { DailySummaryDTO(day: $0, restingHeartRate: 50, avgStress: 25) }
    }

    func hrvSummaries(from: Day, to: Day) async throws -> [HRVSummaryDTO] {
        froms.append(from)
        hrvFroms.append(from)
        return days(from: from, to: to).map {
            HRVSummaryDTO(day: $0, lastNightAvg: 60, weeklyAvg: 58, status: "BALANCED", baselineLowUpper: 40, baselineBalancedLow: 50, baselineBalancedUpper: 70)
        }
    }

    func sleepSummaries(from: Day, to: Day) async throws -> [SleepDTO] {
        froms.append(from)
        sleepFroms.append(from)
        if let sleepFailure, sleepFailure.from == from { throw sleepFailure.error }
        return days(from: from, to: to).map {
            SleepDTO(day: $0, sleepTimeSeconds: 27_000, deepSleepSeconds: 5_400, lightSleepSeconds: 14_400, remSleepSeconds: 5_400, awakeSleepSeconds: 1_800, overallScore: 80, sleepEndTimestampGMT: Self.sleepEndMs($0))
        }
    }

    func bodyBattery(from: Day, to: Day) async throws -> [BodyBatteryDayDTO] {
        froms.append(from)
        batteryFroms.append(from)
        return days(from: from, to: to).map { day in
            let end = Self.sleepEndMs(day)
            let hour: Int64 = 3_600_000
            return BodyBatteryDayDTO(day: day, charged: 60, drained: 40, samples: [
                BodyBatterySampleDTO(timestampMs: end - hour, value: 30),
                BodyBatterySampleDTO(timestampMs: end + hour, value: 85),
                BodyBatterySampleDTO(timestampMs: end + 4 * hour, value: 95),
            ])
        }
    }

    func activities(start: Int, limit: Int, from: Day?, to: Day?) async throws -> [ActivityDTO] {
        if let from { froms.append(from) }
        activityPageStarts.append(start)
        if let activityFailure, activityFailure.start == start { throw activityFailure.error }
        let filtered = activityList.filter { dto in
            guard let from, let local = dto.startTimeLocal, let day = Day(iso: String(local.prefix(10))) else { return true }
            return day >= from
        }
        guard start < filtered.count else { return [] }
        return Array(filtered[start..<min(start + limit, filtered.count)])
    }

    func fitArchive(activityId: Int64) async throws -> Data {
        fitCalls.append(activityId)
        if cancelledFITs.contains(activityId) { throw CancellationError() }
        if let error = fitErrors[activityId] { throw error }
        guard let fitZip else { throw FakeFITError() }
        return fitZip
    }

    private func days(from: Day, to: Day) -> [Day] {
        guard let dataDays else { return [] }
        let lower = max(from, dataDays.lowerBound)
        let upper = min(to, dataDays.upperBound)
        guard lower <= upper else { return [] }
        return (0...lower.days(until: upper)).map { lower.adding(days: $0) }
    }

    static func sleepEndMs(_ day: Day) -> Int64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
        return Int64(midnight.timeIntervalSince1970 * 1000) + 9 * 3_600_000
    }

    static func activity(id: Int64, typeKey: String, day: Day, hour: Int = 7, load: Double? = nil) -> ActivityDTO {
        ActivityDTO(
            activityId: id,
            activityName: "Atividade \(id)",
            typeKey: typeKey,
            startTimeLocal: "\(day.iso) " + String(format: "%02d:00:00", hour),
            distance: 10_000,
            duration: 3_000,
            activityTrainingLoad: load,
            hrTimeInZone: [60, 600, 1_500, 700, 140]
        )
    }
}
