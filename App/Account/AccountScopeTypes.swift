import Foundation

struct AccountChatStores: Sendable {
    let workouts: WorkoutChatStore
    let races: WorkoutChatStore
    let evolution: WorkoutChatStore
    let planned: WorkoutChatStore
    let trainer: WorkoutChatStore

    init(folder: URL) {
        workouts = WorkoutChatStore(folder: folder.appending(path: WorkoutChatConstants.folderName))
        races = WorkoutChatStore(folder: folder.appending(path: WorkoutChatConstants.raceFolderName))
        evolution = WorkoutChatStore(folder: folder.appending(path: WorkoutChatConstants.evolutionFolderName))
        planned = WorkoutChatStore(folder: folder.appending(path: WorkoutChatConstants.plannedFolderName))
        trainer = WorkoutChatStore(folder: folder.appending(path: TrainerChatConstants.folderName))
    }
}
