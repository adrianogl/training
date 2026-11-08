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
    let fitLimit: Int?
    public private(set) var heartRateZones: HRZonesDTO?
    private var inFlight: InFlightOperation?

    public init(
        source: any GarminDataSource,
        container: ModelContainer,
        today: @escaping @Sendable () -> Day,
        firstDay: Day = Day(iso: "2024-01-01")!,
        fitLimit: Int? = nil
    ) {
        self.modelContainer = container
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(container))
        self.source = source
        self.today = today
        self.firstDay = firstDay
        self.fitLimit = fitLimit
    }

    public func run(progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> SyncReport {
        try await singleFlight(.sync) { try await self.perform(progress: progress) }
    }

    public func reprocess(limit: Int?) async throws -> SyncReport {
        try await singleFlight(.reprocess) { try await self.performReprocess(limit: limit) }
    }

    private func singleFlight(
        _ operation: SyncOperation,
        work: @escaping @Sendable () async throws -> SyncReport
    ) async throws -> SyncReport {
        while let inFlight {
            if inFlight.operation == operation {
                return try await awaitCancellable(inFlight.task)
            }
            _ = await inFlight.task.result
            try Task.checkCancellation()
        }
        let task = Task { try await work() }
        inFlight = InFlightOperation(operation: operation, task: task)
        defer {
            if self.inFlight?.task == task { self.inFlight = nil }
        }
        return try await awaitCancellable(task)
    }

    private func awaitCancellable(_ task: Task<SyncReport, Error>) async throws -> SyncReport {
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func performReprocess(limit: Int?) async throws -> SyncReport {
        try backfillLocalDays()
        let result = try await processFITQueue(try fitQueue(includesNewRuns: false, limit: limit ?? fitLimit)) { _ in }
        var report = SyncReport()
        report.reprocessed = result.reprocessed
        report.fitStoppedByRateLimit = result.stoppedByRateLimit
        return report
    }

    private func perform(progress: @escaping @Sendable (Double) -> Void) async throws -> SyncReport {
        typealias C = SyncConstants
        var report = SyncReport()
        let today = today()
        progress(0)

        report.duplicatesRemoved = try removeDuplicates()
        try backfillLocalDays()
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

        let fit = try await processFITQueue(try fitQueue(includesNewRuns: true, limit: fitLimit)) { fraction in
            progress(C.progressAfterActivities + fraction * (C.progressAfterFIT - C.progressAfterActivities))
        }
        report.fitProcessed = fit.processed
        report.reprocessed = fit.reprocessed
        report.fitStoppedByRateLimit = fit.stoppedByRateLimit
        progress(C.progressAfterFIT)

        try updateReadiness(days: isFirstLoad ? try storedDays() : touchedDays)
        progress(C.progressAfterDerived)

        try Task.checkCancellation()
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
        let zones: HRZonesDTO
        do {
            zones = try await source.heartRateZones()
        } catch let error as GarminAPIError where SyncErrorPolicy.isCredentialFailure(error) {
            throw error
        } catch {
            if SyncErrorPolicy.isCancellation(error) { throw CancellationError() }
            return
        }
        heartRateZones = zones
        try upsertHeartRateZones(zones)
    }

    private func latestActivityStart() throws -> Date? {
        let missing = Date.distantPast
        var descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.start > missing },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.start
    }
}
