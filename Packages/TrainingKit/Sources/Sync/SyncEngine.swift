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

        let from = dailyStart(state: state, today: today)
        let touchedDays = try await syncDaily(from: from, to: today) { fraction in
            progress(C.progressAfterZones + fraction * (C.progressAfterDaily - C.progressAfterZones))
        }
        report.dailyUpserted = touchedDays.count
        progress(C.progressAfterDaily)

        let incrementalCutoff = state.firstLoadCompleted
            ? state.lastActivityStart.map { $0.addingTimeInterval(-C.incrementalActivityOverlap) }
            : nil
        report.activitiesUpserted = try await syncActivities(
            from: state.firstLoadCompleted ? nil : firstDay,
            incrementalCutoff: incrementalCutoff
        ).count
        progress(C.progressAfterActivities)

        report.fitProcessed = try await processPendingFIT { fraction in
            progress(C.progressAfterActivities + fraction * (C.progressAfterFIT - C.progressAfterActivities))
        }
        progress(C.progressAfterFIT)

        try updateReadiness(days: touchedDays)
        progress(C.progressAfterDerived)

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

    private func dailyStart(state: SyncState, today: Day) -> Day {
        guard state.firstLoadCompleted else { return firstDay }
        let overlap = SyncConstants.incrementalOverlapDays
        let overlapStart = today.adding(days: -overlap)
        guard let lastSync = state.lastSync else { return overlapStart }
        return min(overlapStart, ActivityTime.day(of: lastSync).adding(days: -overlap))
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
