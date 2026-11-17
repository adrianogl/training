import Foundation

struct AccountChatStores: Sendable {
    let workouts: WorkoutChatStore
    let races: WorkoutChatStore
    let evolution: WorkoutChatStore
    let planned: WorkoutChatStore
    let trainer: WorkoutChatStore
    let syncFolders: [ChatFolder]

    init(folder: URL) {
        workouts = WorkoutChatStore(folder: folder.appending(path: WorkoutChatConstants.folderName))
        races = WorkoutChatStore(folder: folder.appending(path: WorkoutChatConstants.raceFolderName))
        evolution = WorkoutChatStore(folder: folder.appending(path: WorkoutChatConstants.evolutionFolderName))
        planned = WorkoutChatStore(folder: folder.appending(path: WorkoutChatConstants.plannedFolderName))
        trainer = WorkoutChatStore(folder: folder.appending(path: TrainerChatConstants.folderName))
        syncFolders = [
            ChatFolder(tag: DeviceSyncConstants.workoutTag, url: folder.appending(path: WorkoutChatConstants.folderName)),
            ChatFolder(tag: DeviceSyncConstants.raceTag, url: folder.appending(path: WorkoutChatConstants.raceFolderName)),
            ChatFolder(tag: DeviceSyncConstants.evolutionTag, url: folder.appending(path: WorkoutChatConstants.evolutionFolderName)),
            ChatFolder(tag: DeviceSyncConstants.plannedTag, url: folder.appending(path: WorkoutChatConstants.plannedFolderName)),
            ChatFolder(tag: DeviceSyncConstants.trainerTag, url: folder.appending(path: TrainerChatConstants.folderName)),
        ]
    }

    func reload() async {
        for store in [workouts, races, evolution, planned, trainer] { await store.reload() }
    }
}
