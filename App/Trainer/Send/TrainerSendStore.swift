import Foundation
import TrainingCore

struct TrainerSendStore {
    var defaults: UserDefaults = AccountScope.current.defaults
    var now: () -> Date = { .now }

    private typealias C = TrainerSendConstants

    func records() -> [String: TrainerSentRecord] {
        ledger().entries.compactMapValues(\.record)
    }

    func record(_ record: TrainerSentRecord, key: String) {
        update { $0.entries[key] = TrainerSendLedgerEntry(record: record, updatedAt: now()) }
    }

    func remove(key: String) {
        update { $0.entries[key] = TrainerSendLedgerEntry(record: nil, updatedAt: now()) }
    }

    func orphans() -> [Int64] {
        ledger().orphans
    }

    func clearOrphan(_ workoutId: Int64) {
        update { $0.orphans.removeAll { $0 == workoutId } }
    }

    func ledger() -> TrainerSendLedger {
        if let data = defaults.data(forKey: C.ledgerKey), let ledger = try? JSONDecoder().decode(TrainerSendLedger.self, from: data) {
            return ledger
        }
        guard let data = defaults.data(forKey: C.recordsKey),
              let legacy = try? JSONDecoder().decode([String: TrainerSentRecord].self, from: data) else { return TrainerSendLedger() }
        return TrainerSendLedger(entries: legacy.mapValues { TrainerSendLedgerEntry(record: $0, updatedAt: now()) })
    }

    @discardableResult
    func merge(remote: TrainerSendLedger) -> TrainerSendLedger {
        var merged = Self.merged(local: ledger(), remote: remote)
        merged = pruned(merged)
        write(merged)
        return merged
    }

    static func merged(local: TrainerSendLedger, remote: TrainerSendLedger) -> TrainerSendLedger {
        var result = TrainerSendLedger(orphans: Array(Set(local.orphans + remote.orphans)).sorted())
        var lost: [Int64] = []
        for key in Set(local.entries.keys).union(remote.entries.keys) {
            let mine = local.entries[key]
            let theirs = remote.entries[key]
            let winner: TrainerSendLedgerEntry? = switch (mine, theirs) {
            case let (mine?, theirs?): theirs.updatedAt > mine.updatedAt ? theirs : mine
            case let (mine?, nil): mine
            case let (nil, theirs?): theirs
            case (nil, nil): nil
            }
            result.entries[key] = winner
            for entry in [mine, theirs].compactMap({ $0 }) {
                if let id = entry.record?.workoutId, id != winner?.record?.workoutId { lost.append(id) }
            }
        }
        let active = Set(result.entries.values.compactMap { $0.record?.workoutId })
        result.orphans = Array(Set(result.orphans + lost).subtracting(active)).sorted()
        return result
    }

    func settings() -> TrainerSendSettings {
        guard let data = defaults.data(forKey: C.settingsKey),
              let settings = try? JSONDecoder().decode(TrainerSendSettings.self, from: data) else { return TrainerSendSettings() }
        return settings
    }

    func save(_ settings: TrainerSendSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: C.settingsKey)
    }

    private func update(_ change: (inout TrainerSendLedger) -> Void) {
        var current = ledger()
        change(&current)
        write(pruned(current))
        SyncDocumentStamp(defaults: defaults, syncedKey: C.ledgerSyncedStampKey, documentKey: C.ledgerDocumentStampKey)
            .bumpForLocalChange(newestEntry: current.updatedAt, now: now())
    }

    private func pruned(_ ledger: TrainerSendLedger) -> TrainerSendLedger {
        let oldest = Day.today(now: now()).adding(days: -C.ledgerKeepDays)
        var result = ledger
        result.entries = ledger.entries.filter { _, entry in
            guard let day = entry.record.flatMap({ Day(iso: $0.day) }) else { return entry.updatedAt > now().addingTimeInterval(-Double(C.ledgerKeepDays) * 86_400) }
            return day >= oldest
        }
        return result
    }

    private func write(_ ledger: TrainerSendLedger) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(ledger) else { return }
        defaults.set(data, forKey: C.ledgerKey)
        defaults.removeObject(forKey: C.recordsKey)
    }
}
