import Foundation
import MFIT
import RemoteSync
import Testing
@testable import trAIning

@Suite struct DeviceSyncTests {
    private static let stamp = Date(timeIntervalSince1970: 1_794_864_600)

    private static func defaults() -> UserDefaults {
        UserDefaults(suiteName: "device-sync-\(UUID().uuidString)")!
    }

    @Test func changedPreferenceIsPendingUntilPushed() {
        let defaults = Self.defaults()
        let store = PreferenceSyncStore(defaults: defaults, now: { Self.stamp })
        defaults.set(50, forKey: AppConstants.weeklyGoalDefaultsKey)
        defaults.set("água no km 7", forKey: CoursePointsConstants.defaultsPrefix + "0F8FAD5B-D9CB-469F-A165-70867728950E")
        defaults.set(true, forKey: "naoSincroniza")

        let pending = store.pendingBlobs()
        store.markBlobsPushed(pending)

        #expect(Set(pending.map(\.id)) == [AppConstants.weeklyGoalDefaultsKey, CoursePointsConstants.defaultsPrefix + "0F8FAD5B-D9CB-469F-A165-70867728950E"])
        #expect(store.pendingBlobs().isEmpty)
        defaults.set(60, forKey: AppConstants.weeklyGoalDefaultsKey)
        #expect(store.pendingBlobs().map(\.id) == [AppConstants.weeklyGoalDefaultsKey])
    }

    @Test func newerRemotePreferenceIsWrittenAndNotSentBack() {
        let source = Self.defaults()
        source.set(70, forKey: AppConstants.weeklyGoalDefaultsKey)
        let blob = PreferenceSyncStore(defaults: source, now: { Self.stamp.addingTimeInterval(60) }).pendingBlobs()[0]
        let defaults = Self.defaults()
        let store = PreferenceSyncStore(defaults: defaults, now: { Self.stamp })
        defaults.set(50, forKey: AppConstants.weeklyGoalDefaultsKey)
        store.markBlobsPushed(store.pendingBlobs())

        #expect(store.apply(blob))
        #expect(defaults.integer(forKey: AppConstants.weeklyGoalDefaultsKey) == 70)
        #expect(store.pendingBlobs().isEmpty)
        #expect(!store.apply(RemoteBlob(id: blob.id, data: blob.data, updatedAt: Self.stamp.addingTimeInterval(-60))))
    }

    @Test func keptDecisionsAndStravaLedgerAreTracked() {
        let defaults = Self.defaults()
        let store = PreferenceSyncStore(defaults: defaults, now: { Self.stamp })
        defaults.set("2026-11-17", forKey: TrainerConstants.readinessKeptDefaultsKey)
        defaults.set("2026-W47", forKey: TrainerMFITConstants.keptDefaultsKey)
        defaults.set(Data("{}".utf8), forKey: StravaConstants.ledgerDefaultsKey)

        #expect(Set(store.pendingBlobs().map(\.id)) == [
            TrainerConstants.readinessKeptDefaultsKey, TrainerMFITConstants.keptDefaultsKey, StravaConstants.ledgerDefaultsKey,
        ])
    }

    @Test func chatsFromTwoDevicesKeepEveryMessage() {
        let first = ChatMessage(role: .user, text: "Como foi o treino?", date: Self.stamp)
        let second = ChatMessage(role: .assistant, text: "Bom.", date: Self.stamp.addingTimeInterval(10))
        let fromIpad = ChatMessage(role: .user, text: "E a subida?", date: Self.stamp.addingTimeInterval(20))

        let merged = ChatSyncStore.merge([first, second], [first, fromIpad])

        #expect(merged.map(\.text) == ["Como foi o treino?", "Bom.", "E a subida?"])
    }

    @Test func remoteChatIsMergedIntoTheFileAndIndex() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "chats-\(UUID().uuidString)")
        let store = ChatSyncStore(folders: [ChatFolder(tag: DeviceSyncConstants.workoutTag, url: folder)], defaults: Self.defaults())
        let local = [ChatMessage(role: .user, text: "Local", date: Self.stamp)]
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(local).write(to: folder.appending(path: "42.json"))
        let remote = [ChatMessage(role: .user, text: "Do iPad", date: Self.stamp.addingTimeInterval(5))]

        #expect(store.apply(RemoteBlob(id: "workout.42", data: try JSONEncoder().encode(remote), updatedAt: Self.stamp)))

        let saved = try JSONDecoder().decode([ChatMessage].self, from: Data(contentsOf: folder.appending(path: "42.json")))
        #expect(saved.map(\.text) == ["Local", "Do iPad"])
        #expect(store.pendingBlobs().map(\.id) == ["workout.42"])
        let index = try JSONDecoder().decode([[Int64]].self, from: Data(contentsOf: folder.appending(path: WorkoutChatConstants.indexName)))
        #expect(index == [[42, 2]])
    }

    @Test func strengthCachesFromTwoDevicesKeepEveryLoad() {
        let mfit = MFITLoadRecord(exercise: "Agachamento", key: "agachamento", day: "2026-11-16", loads: [60], workoutId: 7)
        let watch = MFITLoadRecord(exercise: "Supino", key: "supino", day: "2026-11-17", loads: [40], workoutId: 8, fromWatch: true)
        let iphone = StrengthProgramCache(program: nil, known: [], loads: [mfit], watchProcessed: [1])
        let ipad = StrengthProgramCache(program: nil, known: [], loads: [mfit, watch], watchProcessed: [2])

        let merged = StrengthSyncStore.merge(local: iphone, remote: ipad, remoteIsNewer: true)

        #expect(merged.loads.map(\.key) == ["agachamento", "supino"])
        #expect(merged.watchProcessed == [1, 2])
    }

    @Test func preferenceStoreLeavesStrengthToItsOwnStore() {
        let store = PreferenceSyncStore(defaults: Self.defaults())

        #expect(!store.handles(DeviceSyncConstants.strengthId))
        #expect(store.handles(AppConstants.weeklyGoalDefaultsKey))
    }

    @Test func notifiedListsFromTwoDevicesAreJoined() {
        let source = Self.defaults()
        source.set(["a", "b"], forKey: StrengthConstants.recordNotifiedKey)
        let blob = PreferenceSyncStore(defaults: source, now: { Self.stamp }).pendingBlobs()[0]
        let defaults = Self.defaults()
        let store = PreferenceSyncStore(defaults: defaults, now: { Self.stamp.addingTimeInterval(60) })
        defaults.set(["c"], forKey: StrengthConstants.recordNotifiedKey)
        store.markBlobsPushed(store.pendingBlobs())

        #expect(store.apply(blob))
        #expect(defaults.stringArray(forKey: StrengthConstants.recordNotifiedKey) == ["c", "a", "b"])
        #expect(store.pendingBlobs().map(\.id) == [StrengthConstants.recordNotifiedKey])
    }

    @Test func watchTokenTravelsToTheOtherDevice() {
        let phone = WatchTokenSyncStore(tokenStore: MemoryKeyStore("token-do-iphone"), defaults: Self.defaults(), now: { Self.stamp })
        let tablet = MemoryKeyStore()
        let ipad = WatchTokenSyncStore(tokenStore: tablet, defaults: Self.defaults(), now: { Self.stamp })

        let blobs = phone.pendingBlobs()
        phone.markBlobsPushed(blobs)

        #expect(blobs.map(\.id) == [DeviceSyncConstants.watchTokenId])
        #expect(phone.pendingBlobs().isEmpty)
        #expect(ipad.pendingBlobs().isEmpty)
        #expect(ipad.apply(blobs[0]))
        #expect((try? tablet.read()) == "token-do-iphone")
        #expect(ipad.pendingBlobs().isEmpty)
    }
}
