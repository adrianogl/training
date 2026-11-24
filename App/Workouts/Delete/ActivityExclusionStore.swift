import Foundation

struct ActivityExclusionStore: Sendable {
    let url: URL

    init(url: URL = AccountScope.current.activityExclusionsURL) {
        self.url = url
    }

    func load() -> ActivityExclusions {
        guard let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(ActivityExclusions.self, from: data) else { return ActivityExclusions() }
        return value
    }

    func save(_ value: ActivityExclusions) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    var deletedIds: Set<Int64> { Set(load().deleted) }

    func isOwn(_ id: Int64) -> Bool { load().own.contains(id) }

    func markDeleted(_ id: Int64) {
        save(load().merged(with: ActivityExclusions(deleted: [id])))
    }

    func markOwn(_ id: Int64) {
        let current = load()
        guard !current.own.contains(id) else { return }
        save(current.merged(with: ActivityExclusions(own: [id])))
    }
}
