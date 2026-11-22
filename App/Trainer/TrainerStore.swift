import Foundation
import Insights
import RemoteSync
import TrainingCore

struct TrainerStore: Sendable {
    let url: URL
    nonisolated(unsafe) let defaults: UserDefaults
    let now: @Sendable () -> Date

    init(url: URL = AccountScope.current.trainerURL, defaults: UserDefaults = AccountScope.current.defaults, now: @escaping @Sendable () -> Date = { .now }) {
        self.url = url
        self.defaults = defaults
        self.now = now
    }

    var seenVersion: Int {
        defaults.integer(forKey: TrainerConstants.seenVersionDefaultsKey)
    }

    var strengthMigrated: Bool {
        defaults.bool(forKey: TrainerConstants.strengthMigratedDefaultsKey)
    }

    func markStrengthMigrated() {
        defaults.set(true, forKey: TrainerConstants.strengthMigratedDefaultsKey)
    }

    func markSeen(_ version: Int) {
        defaults.set(version, forKey: TrainerConstants.seenVersionDefaultsKey)
    }

    var seenCycleEnd: Day? {
        defaults.string(forKey: TrainerConstants.seenCycleEndDefaultsKey).flatMap(Day.init(iso:))
    }

    var keptDaysCycleEnd: Day? {
        defaults.string(forKey: TrainerConstants.keptDaysCycleEndDefaultsKey).flatMap(Day.init(iso:))
    }

    func markDaysKept(_ day: Day) {
        defaults.set(day.iso, forKey: TrainerConstants.keptDaysCycleEndDefaultsKey)
    }

    func markCycleSeen(_ day: Day) {
        defaults.set(day.iso, forKey: TrainerConstants.seenCycleEndDefaultsKey)
    }

    func cycleSummaries() -> [TrainerCycleSummary] {
        guard let data = defaults.data(forKey: TrainerConstants.cycleSummariesDefaultsKey) else { return [] }
        return (try? Self.decoder.decode([TrainerCycleSummary].self, from: data)) ?? []
    }

    func archive(_ summary: TrainerCycleSummary) {
        var summaries = cycleSummaries()
        guard !summaries.contains(where: { $0.id == summary.id }) else { return }
        summaries.append(summary)
        guard let data = try? Self.encoder.encode(summaries) else { return }
        defaults.set(data, forKey: TrainerConstants.cycleSummariesDefaultsKey)
    }

    func load() -> TrainerPlan? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(TrainerPlan.self, from: data)
    }

    func save(_ plan: TrainerPlan) throws {
        try Self.encoder.encode(plan).write(to: url, options: .atomic)
        recordChange(deleted: false)
    }

    func delete() throws {
        defaults.removeObject(forKey: TrainerConstants.seenVersionDefaultsKey)
        defaults.removeObject(forKey: TrainerConstants.strengthMigratedDefaultsKey)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
        recordChange(deleted: true)
    }

    private var isTombstone: Bool {
        defaults.bool(forKey: TrainerConstants.syncDeletedDefaultsKey)
    }

    private var storedStamp: Date? {
        (defaults.object(forKey: TrainerConstants.syncUpdatedAtDefaultsKey) as? Double).map(Date.init(timeIntervalSince1970:))
    }

    private var legacyStamp: Date? {
        guard storedStamp == nil,
              let modified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        else { return nil }
        return Self.rounded(modified)
    }

    private var needsPush: Bool {
        (defaults.object(forKey: TrainerConstants.syncNeedsPushDefaultsKey) as? Bool) ?? (legacyStamp != nil)
    }

    private func recordChange(deleted: Bool) {
        let floor = storedStamp.map { $0.addingTimeInterval(0.001) } ?? .distantPast
        store(stamp: max(Self.rounded(now()), floor), deleted: deleted, needsPush: true)
    }

    private func store(stamp: Date, deleted: Bool, needsPush: Bool) {
        defaults.set(stamp.timeIntervalSince1970, forKey: TrainerConstants.syncUpdatedAtDefaultsKey)
        defaults.set(deleted, forKey: TrainerConstants.syncDeletedDefaultsKey)
        defaults.set(needsPush, forKey: TrainerConstants.syncNeedsPushDefaultsKey)
    }

    private static func rounded(_ date: Date) -> Date {
        Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds(date)) / 1_000)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension TrainerStore: RemoteTrainerStore {
    func updatedAt() -> Date? {
        storedStamp ?? legacyStamp
    }

    func pending() -> RemoteTrainerState? {
        guard needsPush, let stamp = updatedAt() else { return nil }
        if isTombstone { return RemoteTrainerState(data: nil, updatedAt: stamp) }
        guard load() != nil, let data = try? Data(contentsOf: url) else { return nil }
        return RemoteTrainerState(data: data, updatedAt: stamp)
    }

    func markPending() {
        guard let stamp = updatedAt() else { return }
        store(stamp: stamp, deleted: isTombstone, needsPush: true)
    }

    func markPushed(updatedAt pushed: Date) {
        guard updatedAt() == pushed else { return }
        store(stamp: pushed, deleted: isTombstone, needsPush: false)
    }

    func apply(_ remote: RemoteTrainerState) -> Bool {
        guard let data = remote.data else {
            try? FileManager.default.removeItem(at: url)
            defaults.removeObject(forKey: TrainerConstants.seenVersionDefaultsKey)
            defaults.removeObject(forKey: TrainerConstants.strengthMigratedDefaultsKey)
            store(stamp: remote.updatedAt, deleted: true, needsPush: false)
            return true
        }
        guard (try? Self.decoder.decode(TrainerPlan.self, from: data)) != nil, (try? data.write(to: url, options: .atomic)) != nil else { return false }
        markStrengthMigrated()
        store(stamp: remote.updatedAt, deleted: false, needsPush: false)
        return true
    }
}
