import Foundation
import Insights
import RemoteSync
import Storage
import Testing
import TrainingCore
@testable import trAIning

struct StrengthPlanStoreTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private let today = Day(iso: "2026-11-24")!

    private func makeStore() -> (StrengthPlanStore, StrengthPlanSyncStore) {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let defaults = UserDefaults(suiteName: "plan-" + UUID().uuidString)!
        let store = StrengthPlanStore(url: folder.appending(path: "plan.json"), stamps: SyncDocumentStamp(defaults: defaults, syncedKey: StrengthPlanStoreConstants.syncedStampKey, documentKey: StrengthPlanStoreConstants.documentStampKey))
        return (store, StrengthPlanSyncStore(store: store, defaults: defaults))
    }

    private func session(_ weekday: Int, source: TrainerStrengthSource = .trainer, group: TrainerStrengthGroup = .upper) -> TrainerStrengthSession {
        TrainerStrengthSession(weekday: weekday, group: group, legLoad: .light, name: "S", source: source)
    }

    private func plan() -> StrengthPlan {
        StrengthPlan(objective: .strength, sessions: [session(2)], start: today, validity: .weeks(4), builder: .trainer)
    }

    @Test func store_saves_before_sync_and_merges_newer() throws {
        let (store, sync) = makeStore()
        try store.save(plan(), at: base)
        #expect(store.current() != nil)
        let blobs = sync.pendingBlobs()
        #expect(blobs.first?.id == "strengthPlan")
        sync.markBlobsPushed(blobs)
        #expect(sync.pendingBlobs().isEmpty)

        var newer = plan()
        newer.objective = .prevention
        #expect(store.merge(remote: StrengthPlanDocument(plan: newer, updatedAt: base.addingTimeInterval(10), migrated: false)))
        #expect(store.current()?.objective == .prevention)
        #expect(!store.merge(remote: StrengthPlanDocument(plan: plan(), updatedAt: base.addingTimeInterval(5), migrated: false)))
        #expect(store.current()?.objective == .prevention)
    }

    @Test func clear_syncs_as_tombstone_and_is_not_resurrected() throws {
        let (store, sync) = makeStore()
        let saved = plan()
        try store.save(saved, at: base)
        sync.markBlobsPushed(sync.pendingBlobs())
        try store.clear(at: base.addingTimeInterval(20))
        #expect(store.current() == nil)
        #expect(sync.pendingBlobs().count == 1)
        #expect(!store.merge(remote: StrengthPlanDocument(plan: saved, updatedAt: base, migrated: false)))
        #expect(store.current() == nil)
    }

    @Test func migration_with_running_plan_ends_with_it() throws {
        let end = Day(iso: "2027-02-14")!
        let result = StrengthPlanMigration.migrate(sessions: [session(2), session(4, group: .core)], runningPlanEnd: end, today: today)
        #expect(result?.validity == .untilDate(end))
        #expect(result?.start == today)
        #expect(result?.builder == .trainer)
        #expect(result?.migrated == true)
        #expect(result?.objective == .strength)
    }

    @Test func migration_without_running_plan_is_12_weeks() {
        let result = StrengthPlanMigration.migrate(sessions: [session(2, group: .core)], runningPlanEnd: nil, today: today)
        #expect(result?.validity == .weeks(12))
        #expect(result?.objective == .mobility)
    }

    @Test func migration_keeps_only_trainer_sessions() {
        let result = StrengthPlanMigration.migrate(sessions: [session(2), session(3, source: .mfit)], runningPlanEnd: nil, today: today)
        #expect(result?.sessions.count == 1)
        #expect(StrengthPlanMigration.migrate(sessions: [session(3, source: .mfit)], runningPlanEnd: nil, today: today) == nil)
    }

    @Test func migration_runs_once() throws {
        let (store, _) = makeStore()
        #expect(try store.migrateIfNeeded(sessions: [session(2)], runningPlanEnd: nil, today: today, now: base))
        #expect(store.current() != nil)
        try store.clear(at: base.addingTimeInterval(5))
        #expect(try !store.migrateIfNeeded(sessions: [session(2)], runningPlanEnd: nil, today: today, now: base.addingTimeInterval(9)))
        #expect(store.current() == nil)
    }

    @Test func migration_never_beats_remote_tombstone() throws {
        let (store, _) = makeStore()
        try store.migrateIfNeeded(sessions: [session(2)], runningPlanEnd: nil, today: today, now: base.addingTimeInterval(500))
        #expect(store.current() != nil)
        #expect(store.merge(remote: StrengthPlanDocument(plan: nil, updatedAt: base, migrated: true)))
        #expect(store.current() == nil)
    }

    @Test func two_devices_migrating_converge_without_loss() throws {
        let (a, _) = makeStore()
        let (b, _) = makeStore()
        try a.migrateIfNeeded(sessions: [session(2)], runningPlanEnd: nil, today: today, now: base)
        try b.migrateIfNeeded(sessions: [session(2)], runningPlanEnd: nil, today: today, now: base.addingTimeInterval(7))
        _ = a.merge(remote: b.document())
        _ = b.merge(remote: a.document())
        #expect(a.current() != nil)
        #expect(a.current()?.id == b.current()?.id)
    }

    @Test func migrated_plan_loses_to_any_remote_plan() throws {
        let (store, _) = makeStore()
        try store.migrateIfNeeded(sessions: [session(2)], runningPlanEnd: nil, today: today, now: base)
        let remote = plan()
        #expect(store.merge(remote: StrengthPlanDocument(plan: remote, updatedAt: base.addingTimeInterval(-1_000_000), migrated: true)))
        #expect(store.current()?.id == remote.id)
    }

    @Test func migration_with_running_plan_ending_today_uses_it() {
        let result = StrengthPlanMigration.migrate(sessions: [session(2)], runningPlanEnd: today, today: today)
        #expect(result?.validity == .untilDate(today))
    }

    @Test func migration_with_running_plan_already_ended_is_12_weeks() {
        let result = StrengthPlanMigration.migrate(sessions: [session(2)], runningPlanEnd: today.adding(days: -1), today: today)
        #expect(result?.validity == .weeks(12))
    }

    @Test func corrupt_file_is_preserved_before_overwrite() throws {
        let (store, _) = makeStore()
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("nao e json".utf8).write(to: store.url)
        try store.save(plan(), at: base)
        let siblings = try FileManager.default.contentsOfDirectory(atPath: store.url.deletingLastPathComponent().path)
        #expect(siblings.contains { $0.contains(".corrupt-") })
        #expect(store.current() != nil)
    }

    @MainActor @Test func remote_plan_updates_trainer_model() throws {
        let (store, sync) = makeStore()
        let model = TrainerModel(
            container: try TrainingSchema.container(inMemory: true),
            store: TrainerStore(url: FileManager.default.temporaryDirectory.appending(path: "t-\(UUID().uuidString).json"), defaults: UserDefaults(suiteName: "t-\(UUID().uuidString)")!),
            strengthPlanStore: store
        )
        #expect(model.strengthPlan == nil)
        let remote = StrengthPlanDocument(plan: plan(), updatedAt: base, migrated: false)
        let data = try JSONEncoder().encode(remote)
        #expect(sync.apply(RemoteBlob(id: "strengthPlan", data: data, updatedAt: base)))
        model.reloadStrengthPlan()
        #expect(model.strengthPlan == remote.plan)
    }

    @MainActor @Test func model_migrates_trainer_sessions_with_running_plan_end() async throws {
        let (store, _) = makeStore()
        let monday = today.weekStart
        let race = monday.adding(days: 70)
        let model = TrainerModel(
            container: try TrainingSchema.container(inMemory: true),
            store: TrainerStore(url: FileManager.default.temporaryDirectory.appending(path: "t-\(UUID().uuidString).json"), defaults: UserDefaults(suiteName: "t-\(UUID().uuidString)")!),
            today: { monday },
            strengthPlanStore: store
        )
        let target = TrainerTarget(kind: .race, name: "Meia", date: race, distanceMeters: 21_097.5, goalSeconds: 5_940)
        await model.createPlan(target: target, structure: TrainerEngine.defaultStructure, strength: [session(2), session(3, source: .mfit)], startMeters: 60_000, peakMeters: 80_000)
        model.migrateStrengthPlan()
        let migrated = try #require(model.strengthPlan)
        #expect(migrated.validity == .untilDate(race))
        #expect(migrated.sessions.allSatisfy { $0.source == .trainer })
        #expect(migrated.migrated)
        #expect(store.current() == migrated)
    }

    @Test func migrated_stamp_formats_as_server_valid_string() {
        #expect(RemoteTimestamp.string(from: StrengthPlanStoreConstants.migratedStamp) == "2000-01-01T00:00:00.001Z")
    }

    @Test func migrated_plan_is_pushed_with_server_valid_stamp() throws {
        let (store, sync) = makeStore()
        try store.migrateIfNeeded(sessions: [session(2)], runningPlanEnd: nil, today: today, now: base)
        let blob = try #require(sync.pendingBlobs().first)
        #expect(RemoteTimestamp.string(from: blob.updatedAt) == "2000-01-01T00:00:00.001Z")
    }
}
