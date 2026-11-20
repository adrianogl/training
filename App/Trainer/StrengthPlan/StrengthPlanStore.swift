import Foundation
import Insights
import TrainingCore

struct StrengthPlanStore: Sendable {
    let url: URL
    let stamps: SyncDocumentStamp?
    var moveAside: @Sendable (URL, URL) throws -> Void = { try FileManager.default.moveItem(at: $0, to: $1) }

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
            try preserveCorruptFile()
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
            try preserveCorruptFile()
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
        try Self.lock.withLock {
            try preserveCorruptFile()
            var doc = load()
            guard doc.plan == nil, !doc.migrated else { return false }
            doc.migrated = true
            let plan = StrengthPlanMigration.migrate(sessions: sessions, runningPlanEnd: runningPlanEnd, today: today, now: now)
            if let plan {
                doc.plan = plan
                doc.updatedAt = StrengthPlanStoreConstants.migratedStamp
            }
            try write(doc)
            return plan != nil
        }
    }

    func merge(remote: StrengthPlanDocument) -> Bool {
        let applied = try? Self.lock.withLock { () -> Bool in
            try preserveCorruptFile()
            let local = load()
            guard Self.remoteWins(remote, over: local) else { return false }
            var incoming = remote
            incoming.migrated = remote.migrated || local.migrated
            guard incoming != local else { return false }
            try write(incoming)
            return true
        }
        return applied ?? false
    }

    private static func remoteWins(_ remote: StrengthPlanDocument, over local: StrengthPlanDocument) -> Bool {
        if remote.updatedAt != local.updatedAt { return remote.updatedAt > local.updatedAt }
        guard let remotePlan = remote.plan, let localPlan = local.plan else { return false }
        return remotePlan.id.uuidString > localPlan.id.uuidString
    }

    private func preserveCorruptFile() throws {
        guard let data = try? Data(contentsOf: url), (try? JSONDecoder().decode(StrengthPlanDocument.self, from: data)) == nil else { return }
        let stamp = Int(Date().timeIntervalSince1970 * 1_000)
        let aside = url.deletingLastPathComponent().appending(path: url.lastPathComponent + ".corrupt-\(stamp)")
        try moveAside(url, aside)
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
