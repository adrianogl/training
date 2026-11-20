import Foundation
import RemoteSync
import Testing
@testable import trAIning

struct ExerciseFeedbackTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private let key = ExerciseKey.catalog("squat")

    private func makeStore() -> (ExerciseFeedbackStore, ExerciseFeedbackSyncStore, URL) {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "feedback.json")
        let defaults = UserDefaults(suiteName: "feedback-" + UUID().uuidString)!
        let store = ExerciseFeedbackStore(url: url)
        return (store, ExerciseFeedbackSyncStore(store: store, defaults: defaults), url)
    }

    private func entry(
        id: UUID = UUID(),
        key: ExerciseKey? = nil,
        media: String = "freeExerciseDb:A.jpg",
        chosen: String? = nil,
        at offset: TimeInterval = 0,
        status: ExerciseFeedbackStatus = .pending
    ) -> ExerciseFeedback {
        ExerciseFeedback(
            id: id, exercise: key ?? self.key, exerciseName: "Agachamento", mediaId: media,
            verdict: chosen == nil ? .matches : .doesNotMatch, chosenMediaId: chosen, noneMatched: false, note: nil,
            createdAt: base, updatedAt: base.addingTimeInterval(offset), workoutDay: nil, status: status, resolution: nil, resolvedIn: nil
        )
    }

    @Test func save_writes_file_before_sync() throws {
        let (store, _, url) = makeStore()
        let saved = entry()
        try store.save(saved)
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([ExerciseFeedback].self, from: data)
        #expect(decoded == [saved])
    }

    @Test func pending_until_pushed_then_not_pending() {
        let (store, sync, _) = makeStore()
        try? store.save(entry(at: 5))
        let blobs = sync.pendingBlobs()
        #expect(blobs.count == 1)
        #expect(blobs.first?.id == "exerciseFeedback")
        #expect(blobs.first?.updatedAt == base.addingTimeInterval(5))
        sync.markBlobsPushed(blobs)
        #expect(sync.pendingBlobs().isEmpty)
        try? store.save(entry(at: 9))
        #expect(sync.pendingBlobs().count == 1)
    }

    @Test func stale_mark_keeps_newer_entry_pending() {
        let (store, sync, _) = makeStore()
        try? store.save(entry(at: 5))
        let first = sync.pendingBlobs()
        try? store.save(entry(at: 9))
        sync.markBlobsPushed(first)
        let pending = sync.pendingBlobs()
        #expect(pending.count == 1)
        #expect(pending.first?.updatedAt == base.addingTimeInterval(9))
    }

    @Test func unaccepted_mark_keeps_pending() {
        let (store, sync, _) = makeStore()
        try? store.save(entry(at: 5))
        let blobs = sync.pendingBlobs()
        sync.markBlobsPushed([])
        sync.markBlobsPushed([RemoteBlob(id: "strengthContext", data: Data(), updatedAt: base.addingTimeInterval(50))])
        #expect(sync.pendingBlobs().count == 1)
        sync.markBlobsPushed(blobs)
        sync.markBlobsPushed([RemoteBlob(id: "exerciseFeedback", data: Data(), updatedAt: base.addingTimeInterval(1))])
        #expect(sync.pendingBlobs().isEmpty)
        try? store.save(entry(at: 3))
        #expect(sync.pendingBlobs().isEmpty)
    }

    @Test func concurrent_saves_and_merge_lose_nothing() {
        let (store, _, _) = makeStore()
        let remote = (0..<10).map { entry(at: Double(1_000 + $0)) }
        DispatchQueue.concurrentPerform(iterations: 51) { index in
            if index == 50 {
                _ = store.merge(remote)
            } else {
                try? store.save(entry(at: Double(index)))
            }
        }
        #expect(store.all().count == 60)
    }

    @Test func corrupt_file_is_preserved_not_overwritten() throws {
        let (store, _, url) = makeStore()
        let garbage = Data("nao e json".utf8)
        try garbage.write(to: url)
        try store.save(entry())
        #expect(store.all().count == 1)
        let siblings = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        let kept = siblings.filter { $0.lastPathComponent.contains(".corrupt-") }
        #expect(kept.count == 1)
        #expect(try Data(contentsOf: kept[0]) == garbage)
    }

    @Test func corrupt_file_that_cannot_be_moved_is_not_overwritten() throws {
        let (original, _, url) = makeStore()
        let garbage = Data("nao e json".utf8)
        try garbage.write(to: url)
        var store = original
        store.moveAside = { _, _ in throw CocoaError(.fileWriteNoPermission) }
        #expect(throws: (any Error).self) { try store.save(entry()) }
        #expect(!store.merge([entry()]))
        #expect(try Data(contentsOf: url) == garbage)
    }

    @Test func same_stamp_resolution_is_applied() {
        let (store, _, _) = makeStore()
        let id = UUID()
        try? store.save(entry(id: id, at: 4))
        var resolved = entry(id: id, at: 4, status: .resolved)
        resolved.resolution = "ok"
        #expect(store.merge([resolved]))
        #expect(store.all().first?.status == .resolved)
        #expect(!store.merge([entry(id: id, at: 4)]))
        #expect(store.all().first?.status == .resolved)
    }

    @Test func apply_rejects_invalid_or_foreign_blob() {
        let (store, sync, _) = makeStore()
        #expect(!sync.apply(RemoteBlob(id: "exerciseFeedback", data: Data("x".utf8), updatedAt: base)))
        let data = (try? JSONEncoder().encode([entry()])) ?? Data()
        #expect(!sync.apply(RemoteBlob(id: "strengthContext", data: data, updatedAt: base)))
        #expect(store.all().isEmpty)
    }

    @Test func latest_returns_newest_for_key_and_media() {
        let (store, _, _) = makeStore()
        try? store.save(entry(media: "wger:1", at: 1))
        try? store.save(entry(media: "wger:1", at: 7))
        try? store.save(entry(media: "wger:2", at: 9))
        #expect(store.latest(for: key, mediaId: "wger:1")?.updatedAt == base.addingTimeInterval(7))
        #expect(store.latest(for: key, mediaId: "wger:3") == nil)
        #expect(store.latest(for: .mfit("x"), mediaId: "wger:1") == nil)
    }

    @Test func merge_keeps_union_newest_entry_wins() {
        let (store, _, _) = makeStore()
        let shared = UUID()
        try? store.save(entry(id: shared, at: 1))
        var newer = entry(id: shared, at: 10)
        newer.note = "remoto"
        let other = entry(at: 2)
        #expect(store.merge([newer, other]))
        let all = store.all()
        #expect(all.count == 2)
        #expect(all.first { $0.id == shared }?.note == "remoto")
        var older = entry(id: shared, at: 3)
        older.note = "velho"
        #expect(!store.merge([older]))
        #expect(store.all().first { $0.id == shared }?.note == "remoto")
    }

    @Test func merge_never_deletes_local_only_entry() {
        let (store, _, _) = makeStore()
        let local = entry(at: 1)
        try? store.save(local)
        #expect(!store.merge([]))
        #expect(store.all() == [local])
    }

    @Test func resolved_status_from_remote_is_applied() throws {
        let (store, sync, _) = makeStore()
        let id = UUID()
        try? store.save(entry(id: id, at: 1))
        var resolved = entry(id: id, at: 20, status: .resolved)
        resolved.resolution = "troca da imagem"
        resolved.resolvedIn = "1.4.0"
        let data = try JSONEncoder().encode([resolved])
        #expect(sync.apply(RemoteBlob(id: "exerciseFeedback", data: data, updatedAt: resolved.updatedAt)))
        let stored = store.all().first
        #expect(stored?.status == .resolved)
        #expect(stored?.resolution == "troca da imagem")
        #expect(stored?.resolvedIn == "1.4.0")
    }

    @Test func preferred_media_is_latest_chosen_alternative() {
        let (store, _, _) = makeStore()
        try? store.save(entry(chosen: "wger:1", at: 1))
        try? store.save(entry(chosen: "wger:2", at: 5))
        try? store.save(entry(at: 9))
        try? store.save(entry(key: .catalog("other"), chosen: "wger:9", at: 20))
        #expect(store.preferredMediaId(for: key) == "wger:2")
        #expect(store.preferredMediaId(for: .mfit("remada")) == nil)
    }

    @Test func handles_only_its_blob_id() {
        let (_, sync, _) = makeStore()
        #expect(sync.handles("exerciseFeedback"))
        #expect(!sync.handles("strengthContext"))
    }

    private func accept(_ blobs: [RemoteBlob], into server: inout RemoteBlob?) {
        for blob in blobs where server == nil || RemoteTimestamp.milliseconds(blob.updatedAt) > RemoteTimestamp.milliseconds(server!.updatedAt) {
            server = blob
        }
    }

    @Test func union_after_pull_is_pushed_with_newer_stamp() throws {
        let (storeA, syncA, _) = makeStore()
        let (storeB, syncB, _) = makeStore()
        var server: RemoteBlob?
        try storeA.save(entry(at: 5))
        let pushedA = syncA.pendingBlobs()
        accept(pushedA, into: &server)
        syncA.markBlobsPushed(pushedA)
        try storeB.save(entry(key: .catalog("other"), at: 3))
        let pushedB = syncB.pendingBlobs()
        accept(pushedB, into: &server)
        syncB.markBlobsPushed(pushedB)
        #expect(server?.updatedAt == base.addingTimeInterval(5))
        #expect(syncB.apply(server!))
        let next = syncB.pendingBlobs()
        #expect(next.count == 1)
        #expect(next[0].updatedAt > base.addingTimeInterval(5))
        #expect(try JSONDecoder().decode([ExerciseFeedback].self, from: next[0].data).count == 2)
        accept(next, into: &server)
        #expect(try JSONDecoder().decode([ExerciseFeedback].self, from: server!.data).count == 2)
    }

    @Test func echo_of_remote_does_not_repush() throws {
        let (storeA, syncA, _) = makeStore()
        let (_, syncB, _) = makeStore()
        try storeA.save(entry(at: 5))
        let remote = syncA.pendingBlobs()
        #expect(syncB.apply(remote[0]))
        #expect(syncB.pendingBlobs().isEmpty)
    }
}
