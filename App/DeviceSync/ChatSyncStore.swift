import Foundation
import RemoteSync

struct ChatSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.chat
    let folders: [ChatFolder]
    nonisolated(unsafe) let defaults: UserDefaults

    private static let lock = NSLock()
    private typealias C = DeviceSyncConstants

    func pendingBlobs() -> [RemoteBlob] {
        Self.lock.withLock {
            let state = loadState()
            return folders.flatMap { folder in
                files(in: folder).compactMap { name, url -> RemoteBlob? in
                    let id = "\(folder.tag).\(name)"
                    guard let stamp = modified(url), let data = try? Data(contentsOf: url) else { return nil }
                    if let synced = state[id], RemoteTimestamp.milliseconds(synced) >= RemoteTimestamp.milliseconds(stamp) { return nil }
                    return RemoteBlob(id: id, data: data, updatedAt: stamp)
                }
            }
        }
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        Self.lock.withLock {
            var state = loadState()
            for blob in blobs { state[blob.id] = max(state[blob.id] ?? .distantPast, blob.updatedAt) }
            saveState(state)
        }
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        Self.lock.withLock {
            guard let (folder, name) = location(blob.id),
                  let remote = try? JSONDecoder().decode([ChatMessage].self, from: blob.data) else { return false }
            let url = folder.url.appending(path: "\(name).\(C.chatFileExtension)")
            let local = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([ChatMessage].self, from: $0) } ?? []
            let merged = Self.merge(local, remote)
            guard merged != local else { return false }
            try? FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
            guard let data = try? JSONEncoder().encode(merged), (try? data.write(to: url, options: .atomic)) != nil else { return false }
            if merged == remote, let stamp = modified(url) {
                var state = loadState()
                state[blob.id] = stamp
                saveState(state)
            }
            rebuildIndex(folder)
            return true
        }
    }

    static func merge(_ local: [ChatMessage], _ remote: [ChatMessage]) -> [ChatMessage] {
        var seen = Set<UUID>()
        return (local + remote).filter { seen.insert($0.id).inserted }.sorted { $0.date < $1.date }
    }

    private func location(_ id: String) -> (ChatFolder, String)? {
        guard let dot = id.firstIndex(of: ".") else { return nil }
        let tag = String(id[..<dot])
        let name = String(id[id.index(after: dot)...])
        guard Int64(name) != nil, let folder = folders.first(where: { $0.tag == tag }) else { return nil }
        return (folder, name)
    }

    private func files(in folder: ChatFolder) -> [(String, URL)] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder.url, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return urls.compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            guard url.pathExtension == C.chatFileExtension, url.lastPathComponent != C.chatIndexName, Int64(name) != nil else { return nil }
            return (name, url)
        }
    }

    private func modified(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            .map { Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds($0)) / 1_000) }
    }

    private func rebuildIndex(_ folder: ChatFolder) {
        let pairs = files(in: folder).compactMap { name, url -> [Int64]? in
            guard let id = Int64(name), let data = try? Data(contentsOf: url),
                  let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return nil }
            return [id, Int64(messages.filter { $0.role == .user }.count)]
        }
        guard let data = try? JSONEncoder().encode(pairs) else { return }
        try? data.write(to: folder.url.appending(path: C.chatIndexName), options: .atomic)
    }

    private func loadState() -> [String: Date] {
        defaults.data(forKey: C.chatStateKey).flatMap { try? JSONDecoder().decode([String: Date].self, from: $0) } ?? [:]
    }

    private func saveState(_ state: [String: Date]) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: C.chatStateKey)
    }
}
