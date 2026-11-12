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
    let mode: SyncMode
    public private(set) var heartRateZones: HRZonesDTO?
    private var inFlight: InFlightOperation?

    public init(
        source: any GarminDataSource,
        container: ModelContainer,
        today: @escaping @Sendable () -> Day,
        firstDay: Day = Day(iso: "2024-01-01")!,
        fitLimit: Int? = nil,
        mode: SyncMode = .foreground
    ) {
        self.modelContainer = container
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(container))
        self.source = source
        self.today = today
        self.firstDay = firstDay
        self.fitLimit = mode == .background ? SyncConstants.backgroundFitLimit : fitLimit
        self.mode = mode
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
                return try await join(inFlight.task)
            }
            let awaited = inFlight.task
            _ = await awaited.result
            if self.inFlight?.task == awaited { self.inFlight = nil }
            try Task.checkCancellation()
        }
        let task = Task { try await work() }
        inFlight = InFlightOperation(operation: operation, task: task)
        defer {
            if self.inFlight?.task == task { self.inFlight = nil }
        }
        return try await join(task)
    }

    private func join(_ task: Task<SyncReport, Error>) async throws -> SyncReport {
        guard inFlight?.task == task else { return try await task.value }
        inFlight?.awaiters += 1
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { await self.leave(task) }
        }
    }

    private func leave(_ task: Task<SyncReport, Error>) {
        guard inFlight?.task == task, var operation = inFlight else { return }
        operation.awaiters -= 1
        inFlight = operation
        if operation.awaiters <= 0 { task.cancel() }
    }

    private func performReprocess(limit: Int?) async throws -> SyncReport {
        try backfillLocalDays()
        let queue = try fitQueue(includesNewRuns: false, limit: limit ?? fitLimit)
        queue.forEach { $0.fitTransientFailures = 0 }
        try modelContext.save()
        let result = try await processFITQueue(queue) { _ in }
        var report = SyncReport()
        report.reprocessed = result.reprocessed
        report.processedActivityIds = result.activityIds
        report.fitStoppedByRateLimit = result.stoppedByRateLimit
        report.skippedFITs = result.skipped
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
        let touchedDays: Set<Day>
        let upsertedActivities: Set<Int64>
        do {
            touchedDays = try await syncDaily(
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
                : (state.lastActivityStart ?? state.lastSync ?? ActivityTime.startOfDay(firstDay)).addingTimeInterval(-C.incrementalActivityOverlap)
            upsertedActivities = try await syncActivities(
                from: isFirstLoad ? firstDay : nil,
                startAt: isFirstLoad ? max((state.resumeActivityStart ?? 0) - C.activityPageSize, 0) : 0,
                incrementalCutoff: incrementalCutoff,
                state: state,
                tracksResume: isFirstLoad
            )
            report.activitiesUpserted = upsertedActivities.count
            progress(C.progressAfterActivities)
        } catch GarminAPIError.rateLimited(_) where mode == .background {
            try modelContext.save()
            report.stoppedByRateLimit = true
            return report
        }

        let fit = try await processFITQueue(try fitQueue(includesNewRuns: true, limit: fitLimit)) { fraction in
            progress(C.progressAfterActivities + fraction * (C.progressAfterFIT - C.progressAfterActivities))
        }
        report.fitProcessed = fit.processed
        report.reprocessed = fit.reprocessed
        report.processedActivityIds = fit.activityIds
        report.fitStoppedByRateLimit = fit.stoppedByRateLimit
        report.skippedFITs = fit.skipped
        report.stoppedByRateLimit = fit.stoppedByRateLimit
        progress(C.progressAfterFIT)

        let recomputesAll = isFirstLoad || state.readinessVersion < C.readinessVersion
        try updateReadiness(days: recomputesAll ? try storedDays() : touchedDays.union(try loadAffectedDays(upsertedActivities)))
        state.readinessVersion = C.readinessVersion
        try refreshThresholdZoneSeconds(in: modelContext, limit: mode == .background ? C.backgroundThresholdRefreshLimit : nil)
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
        let states = try modelContext.fetch(FetchDescriptor<SyncState>()).sorted { a, b in
            if a.firstLoadCompleted != b.firstLoadCompleted { return a.firstLoadCompleted }
            return (a.lastSync ?? .distantPast) > (b.lastSync ?? .distantPast)
        }
        if let existing = states.first {
            states.dropFirst().forEach(modelContext.delete)
            if states.count > 1 { try modelContext.save() }
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
