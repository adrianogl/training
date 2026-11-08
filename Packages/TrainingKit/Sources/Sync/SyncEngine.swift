import Foundation
import GarminAPI
import Storage
import SwiftData
import TrainingCore

public actor SyncEngine: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    let source: any GarminDataSource
    let today: @Sendable () -> Day
    let firstDay: Day
    public private(set) var heartRateZones: HRZonesDTO?
    private var currentRun: Task<SyncReport, Error>?

    public init(
        source: any GarminDataSource,
        container: ModelContainer,
        today: @escaping @Sendable () -> Day,
        firstDay: Day = Day(iso: "2024-01-01")!
    ) {
        self.modelContainer = container
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(container))
        self.source = source
        self.today = today
        self.firstDay = firstDay
    }

    public func run(progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> SyncReport {
        if let currentRun {
            return try await currentRun.value
        }
        let task = Task { try await self.perform(progress: progress) }
        currentRun = task
        defer { currentRun = nil }
        return try await task.value
    }

    private func perform(progress: @escaping @Sendable (Double) -> Void) async throws -> SyncReport {
        typealias C = SyncConstants
        var report = SyncReport()
        let today = today()
        progress(0)

        report.duplicatesRemoved = try removeDuplicates()
        let state = try syncState()
        progress(C.progressAfterCleanup)

        try await fetchHeartRateZones()
        progress(C.progressAfterZones)

        let isFirstLoad = !state.firstLoadCompleted
        let touchedDays = try await syncDaily(
            starts: dailyStarts(state: state, today: today),
            to: today,
            state: state,
            tracksResume: isFirstLoad
        ) { fraction in
            progress(C.progressAfterZones + fraction * (C.progressAfterDaily - C.progressAfterZones))
        }
        report.dailyUpserted = touchedDays.count
        progress(C.progressAfterDaily)

        let incrementalCutoff = isFirstLoad
            ? nil
            : state.lastActivityStart.map { $0.addingTimeInterval(-C.incrementalActivityOverlap) }
        report.activitiesUpserted = try await syncActivities(
            from: isFirstLoad ? firstDay : nil,
            startAt: isFirstLoad ? state.resumeActivityStart ?? 0 : 0,
            incrementalCutoff: incrementalCutoff,
            state: state,
            tracksResume: isFirstLoad
        ).count
        progress(C.progressAfterActivities)

        report.fitProcessed = try await processPendingFIT { fraction in
            progress(C.progressAfterActivities + fraction * (C.progressAfterFIT - C.progressAfterActivities))
        }
        progress(C.progressAfterFIT)

        try updateReadiness(days: isFirstLoad ? try storedDays() : touchedDays)
        progress(C.progressAfterDerived)

        state.clearResumeCursors()
        state.firstLoadCompleted = true
        state.lastSync = .now
        state.lastActivityStart = try latestActivityStart()
        try modelContext.save()
        progress(1)
        return report
    }

    private func syncState() throws -> SyncState {
        if let existing = try modelContext.fetch(FetchDescriptor<SyncState>()).first {
            return existing
        }
        let state = SyncState()
        modelContext.insert(state)
        try modelContext.save()
        return state
    }

    private func dailyStarts(state: SyncState, today: Day) -> DailyStarts {
        guard state.firstLoadCompleted else {
            func resume(_ cursor: String?) -> Day { cursor.flatMap(Day.init(iso:)) ?? firstDay }
            return DailyStarts(
                summary: resume(state.resumeDailyFrom),
                hrv: resume(state.resumeHRVFrom),
                sleep: resume(state.resumeSleepFrom),
                bodyBattery: resume(state.resumeBodyBatteryFrom)
            )
        }
        let overlap = SyncConstants.incrementalOverlapDays
        let overlapStart = today.adding(days: -overlap)
        guard let lastSync = state.lastSync else { return DailyStarts(all: overlapStart) }
        return DailyStarts(all: min(overlapStart, ActivityTime.day(of: lastSync).adding(days: -overlap)))
    }

    private func storedDays() throws -> Set<Day> {
        var descriptor = FetchDescriptor<DailyRecord>()
        descriptor.propertiesToFetch = [\.day]
        return Set(try modelContext.fetch(descriptor).compactMap { Day(iso: $0.day) })
    }

    private func fetchHeartRateZones() async throws {
        do {
            heartRateZones = try await source.heartRateZones()
        } catch let error as GarminAPIError where SyncErrorPolicy.isCredentialFailure(error) {
            throw error
        } catch {
            return
        }
    }

    private func latestActivityStart() throws -> Date? {
        var descriptor = FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.start
    }
}
