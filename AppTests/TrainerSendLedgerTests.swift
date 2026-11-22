import Foundation
import RemoteSync
import Testing
@testable import trAIning

@Suite struct TrainerSendLedgerTests {
    private func defaults() -> UserDefaults {
        let name = "ledger-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func record(_ id: Int64, day: String = "2026-11-25") -> TrainerSentRecord {
        TrainerSentRecord(workoutId: id, signature: "s\(id)", day: day, kind: .run)
    }

    private let now = Date(timeIntervalSince1970: 1_795_000_000)

    @Test func newerEntryWinsAndLoserBecomesOrphan() {
        let local = TrainerSendLedger(entries: ["a": .init(record: record(1), updatedAt: now)])
        let remote = TrainerSendLedger(entries: ["a": .init(record: record(2), updatedAt: now.addingTimeInterval(60))])

        let merged = TrainerSendStore.merged(local: local, remote: remote)

        #expect(merged.entries["a"]?.record?.workoutId == 2)
        #expect(merged.orphans == [1])
    }

    @Test func removalOnOtherDeviceOrphansTheWorkout() {
        let local = TrainerSendLedger(entries: ["a": .init(record: record(1), updatedAt: now)])
        let remote = TrainerSendLedger(entries: ["a": .init(record: nil, updatedAt: now.addingTimeInterval(60))])

        let merged = TrainerSendStore.merged(local: local, remote: remote)

        #expect(merged.entries["a"]?.record == nil)
        #expect(merged.orphans == [1])
    }

    @Test func sameWorkoutOnBothSidesIsNotOrphan() {
        let entry = TrainerSendLedgerEntry(record: record(1), updatedAt: now)
        let merged = TrainerSendStore.merged(local: .init(entries: ["a": entry]), remote: .init(entries: ["a": entry, "b": .init(record: record(3), updatedAt: now)]))

        #expect(merged.orphans.isEmpty)
        #expect(Set(merged.entries.keys) == ["a", "b"])
    }

    @Test func legacyRecordsMigrateAndSyncRoundTrips() throws {
        let iphone = defaults()
        let ipad = defaults()
        iphone.set(try JSONEncoder().encode(["a": record(1)]), forKey: TrainerSendConstants.recordsKey)
        let phoneStore = TrainerSendStore(defaults: iphone, now: { self.now })
        #expect(phoneStore.records()["a"]?.workoutId == 1)

        phoneStore.record(record(5), key: "b")
        let blobs = TrainerSendSyncStore(defaults: iphone).pendingBlobs()
        #expect(blobs.count == 1)
        #expect(iphone.data(forKey: TrainerSendConstants.recordsKey) == nil)

        TrainerSendStore(defaults: ipad, now: { self.now }).record(record(9), key: "a")
        _ = TrainerSendSyncStore(defaults: ipad).apply(try #require(blobs.first))

        let ipadStore = TrainerSendStore(defaults: ipad, now: { self.now })
        #expect(ipadStore.records()["b"]?.workoutId == 5)
        #expect(Set(ipadStore.orphans() + [ipadStore.records()["a"]!.workoutId]) == [1, 9])
    }
}
