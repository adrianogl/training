import Foundation
import Insights
import RemoteSync
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
}
