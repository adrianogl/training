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
        store.save(saved)
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([ExerciseFeedback].self, from: data)
        #expect(decoded == [saved])
    }

    @Test func pending_until_pushed_then_not_pending() {
        let (store, sync, _) = makeStore()
        store.save(entry(at: 5))
        let blobs = sync.pendingBlobs()
        #expect(blobs.count == 1)
        #expect(blobs.first?.id == "exerciseFeedback")
        #expect(blobs.first?.updatedAt == base.addingTimeInterval(5))
        sync.markBlobsPushed(blobs)
        #expect(sync.pendingBlobs().isEmpty)
        store.save(entry(at: 9))
        #expect(sync.pendingBlobs().count == 1)
    }

    @Test func push_failure_keeps_pending() {
        let (store, sync, _) = makeStore()
        store.save(entry())
        #expect(sync.pendingBlobs().count == 1)
        #expect(sync.pendingBlobs().count == 1)
    }

    @Test func merge_keeps_union_newest_entry_wins() {
        let (store, _, _) = makeStore()
        let shared = UUID()
        store.save(entry(id: shared, at: 1))
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
        store.save(local)
        #expect(!store.merge([]))
        #expect(store.all() == [local])
    }

    @Test func resolved_status_from_remote_is_applied() throws {
        let (store, sync, _) = makeStore()
        let id = UUID()
        store.save(entry(id: id, at: 1))
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
        store.save(entry(chosen: "wger:1", at: 1))
        store.save(entry(chosen: "wger:2", at: 5))
        store.save(entry(at: 9))
        store.save(entry(key: .catalog("other"), chosen: "wger:9", at: 20))
        #expect(store.preferredMediaId(for: key) == "wger:2")
        #expect(store.preferredMediaId(for: .mfit("remada")) == nil)
    }

    @Test func handles_only_its_blob_id() {
        let (_, sync, _) = makeStore()
        #expect(sync.handles("exerciseFeedback"))
        #expect(!sync.handles("strengthContext"))
    }
}
