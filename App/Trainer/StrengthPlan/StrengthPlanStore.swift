import Foundation
import Insights
import TrainingCore

struct StrengthPlanStore: Sendable {
    let url: URL
    let stamps: SyncDocumentStamp?

    private static let lock = NSLock()

    init(url: URL = AccountScope.current.strengthPlanURL, stamps: SyncDocumentStamp? = SyncDocumentStamp(
        defaults: AccountScope.current.defaults, syncedKey: StrengthPlanStoreConstants.syncedStampKey, documentKey: StrengthPlanStoreConstants.documentStampKey
    )) {
        self.url = url
        self.stamps = stamps
    }

    func current() -> StrengthPlan? {
        document().plan
    }

    func document() -> StrengthPlanDocument {
        Self.lock.withLock { load() }
    }

    func isMigrated() -> Bool {
        document().migrated
    }

    func save(_ plan: StrengthPlan, at now: Date = .now) throws {
        let updated = try Self.lock.withLock { () -> Date in
            var doc = load()
            doc.plan = plan
            doc.updatedAt = max(now, doc.updatedAt.addingTimeInterval(0.001))
            try write(doc)
            return doc.updatedAt
        }
        stamps?.bumpForLocalChange(newestEntry: updated)
    }

    func clear(at now: Date = .now) throws {
        let updated = try Self.lock.withLock { () -> Date? in
            var doc = load()
            guard doc.plan != nil else { return nil }
            doc.plan = nil
            doc.updatedAt = max(now, doc.updatedAt.addingTimeInterval(0.001))
            try write(doc)
            return doc.updatedAt
        }
        if let updated { stamps?.bumpForLocalChange(newestEntry: updated) }
    }

    @discardableResult
    func migrateIfNeeded(sessions: [TrainerStrengthSession], runningPlanEnd: Day?, today: Day, now: Date = .now) throws -> Bool {
        let existing = document()
        guard existing.plan == nil, !existing.migrated else { return false }
        guard let plan = StrengthPlanMigration.migrate(sessions: sessions, runningPlanEnd: runningPlanEnd, today: today, now: now) else {
            try Self.lock.withLock {
                var doc = load()
                doc.migrated = true
                try write(doc)
            }
            return false
        }
        try Self.lock.withLock {
            var doc = load()
            doc.migrated = true
            try write(doc)
        }
        try save(plan, at: now)
        return true
    }

    func merge(remote: StrengthPlanDocument) -> Bool {
        let applied = try? Self.lock.withLock { () -> Bool in
            let local = load()
            guard remote.updatedAt > local.updatedAt else { return false }
            var incoming = remote
            incoming.migrated = remote.migrated || local.migrated
            guard incoming != local else { return false }
            try write(incoming)
            return true
        }
        return applied ?? false
    }

    private func load() -> StrengthPlanDocument {
        guard let data = try? Data(contentsOf: url) else { return .empty }
        return (try? JSONDecoder().decode(StrengthPlanDocument.self, from: data)) ?? .empty
    }

    private func write(_ doc: StrengthPlanDocument) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(doc)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
