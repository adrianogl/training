import Foundation

struct JSONFileStore<Element: Codable & Sendable>: Sendable {
    let url: URL
    var moveAside: @Sendable (URL, URL) throws -> Void = { try FileManager.default.moveItem(at: $0, to: $1) }

    private static var lock: NSLock { NSLock.shared(for: Element.self) }

    func read() -> [Element] {
        Self.lock.withLock { load() }
    }

    @discardableResult
    func mutate(_ body: (inout [Element]) throws -> Bool) throws -> Bool {
        try Self.lock.withLock {
            try preserveCorruptFile()
            var elements = load()
            guard try body(&elements) else { return false }
            try write(elements)
            return true
        }
    }

    private func load() -> [Element] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Element].self, from: data)) ?? []
    }

    private func preserveCorruptFile() throws {
        guard let data = try? Data(contentsOf: url), (try? JSONDecoder().decode([Element].self, from: data)) == nil else { return }
        let stamp = Int(Date().timeIntervalSince1970 * 1_000)
        let aside = url.deletingLastPathComponent().appending(path: url.lastPathComponent + ".corrupt-\(stamp)")
        try moveAside(url, aside)
    }

    private func write(_ elements: [Element]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(elements)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

private extension NSLock {
    static let registryLock = NSLock()
    nonisolated(unsafe) static var registry: [ObjectIdentifier: NSLock] = [:]

    static func shared(for type: Any.Type) -> NSLock {
        registryLock.withLock {
            let id = ObjectIdentifier(type)
            if let existing = registry[id] { return existing }
            let created = NSLock()
            registry[id] = created
            return created
        }
    }
}
