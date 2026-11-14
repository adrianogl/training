import Foundation

actor WorkoutChatStore {
    static let shared = WorkoutChatStore()
    static let races = WorkoutChatStore(folder: URL.applicationSupportDirectory.appending(path: WorkoutChatConstants.raceFolderName))
    static let evolution = WorkoutChatStore(folder: URL.applicationSupportDirectory.appending(path: WorkoutChatConstants.evolutionFolderName))
    static let planned = WorkoutChatStore(folder: URL.applicationSupportDirectory.appending(path: WorkoutChatConstants.plannedFolderName))

    private let folder: URL
    private var counts: [Int64: Int]?

    init(folder: URL = URL.applicationSupportDirectory.appending(path: WorkoutChatConstants.folderName)) {
        self.folder = folder
    }

    func messages(for activityId: Int64) -> [ChatMessage] {
        guard let data = try? Data(contentsOf: file(activityId)) else { return [] }
        return (try? JSONDecoder().decode([ChatMessage].self, from: data)) ?? []
    }

    func save(_ messages: [ChatMessage], for activityId: Int64) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(messages) else { return }
        try? data.write(to: file(activityId), options: .atomic)
        var all = loadCounts()
        all[activityId] = messages.filter { $0.role == .user }.count
        counts = all
        if let index = try? JSONEncoder().encode(all.map { [$0.key, Int64($0.value)] }) {
            try? index.write(to: folder.appending(path: WorkoutChatConstants.indexName), options: .atomic)
        }
    }

    func questionCounts() -> [Int64: Int] {
        loadCounts()
    }

    private func loadCounts() -> [Int64: Int] {
        if let counts { return counts }
        let pairs = (try? Data(contentsOf: folder.appending(path: WorkoutChatConstants.indexName)))
            .flatMap { try? JSONDecoder().decode([[Int64]].self, from: $0) } ?? []
        let loaded = Dictionary(pairs.compactMap { $0.count == 2 ? ($0[0], Int($0[1])) : nil }, uniquingKeysWith: { $1 })
        counts = loaded
        return loaded
    }

    private func file(_ activityId: Int64) -> URL {
        folder.appending(path: "\(activityId).json")
    }
}
