import Foundation

struct ScreenSnapshotStore: Sendable {
    let directory: URL
    let version: Int
    let build: String

    init(
        directory: URL = AccountScope.current.snapshotsFolder, version: Int = ScreenSnapshotConstants.schemaVersion,
        build: String = AppBuildInfo().build
    ) {
        self.directory = directory
        self.version = version
        self.build = build
    }

    func save<Payload: Codable>(_ payload: Payload, for kind: ScreenSnapshotKind) {
        let envelope = ScreenSnapshotEnvelope(version: version, build: build, payload: payload)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url(for: kind), options: .atomic)
    }

    func load<Payload: Codable>(_ type: Payload.Type, for kind: ScreenSnapshotKind) -> Payload? {
        guard let data = try? Data(contentsOf: url(for: kind)) else { return nil }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(ScreenSnapshotHeader.self, from: data), header.version == version, header.build == build else { return nil }
        return (try? decoder.decode(ScreenSnapshotEnvelope<Payload>.self, from: data))?.payload
    }

    func remove(_ kind: ScreenSnapshotKind) {
        try? FileManager.default.removeItem(at: url(for: kind))
    }

    func removeAll() {
        ScreenSnapshotKind.allCases.forEach(remove)
    }

    func write<Payload: Codable & Sendable>(_ payload: Payload, for kind: ScreenSnapshotKind) async {
        let store = self
        await Task.detached(priority: .utility) { store.save(payload, for: kind) }.value
    }

    func read<Payload: Codable & Sendable>(_ type: Payload.Type, for kind: ScreenSnapshotKind) async -> Payload? {
        let store = self
        return await Task.detached(priority: .userInitiated) { store.load(type, for: kind) }.value
    }

    private func url(for kind: ScreenSnapshotKind) -> URL {
        directory.appending(path: kind.rawValue).appendingPathExtension(ScreenSnapshotConstants.fileExtension)
    }
}
