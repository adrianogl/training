import Foundation
import RemoteSync

struct SyncDocumentStamp: Sendable {
    nonisolated(unsafe) let defaults: UserDefaults
    let syncedKey: String
    let documentKey: String

    func pendingStamp(newestEntry: Date?) -> Date? {
        let document = defaults.object(forKey: documentKey) as? Double
        let candidates = [newestEntry?.timeIntervalSince1970, document].compactMap { $0 }
        guard let latest = candidates.max() else { return nil }
        let stamp = Self.rounded(Date(timeIntervalSince1970: latest))
        if let synced = defaults.object(forKey: syncedKey) as? Double,
           RemoteTimestamp.milliseconds(Date(timeIntervalSince1970: synced)) >= RemoteTimestamp.milliseconds(stamp) { return nil }
        return stamp
    }

    func markPushed(_ stamp: Date) {
        let current = (defaults.object(forKey: syncedKey) as? Double) ?? 0
        defaults.set(max(current, stamp.timeIntervalSince1970), forKey: syncedKey)
    }

    func bumpForLocalChange(newestEntry: Date?, now: Date = .now) {
        let document = (defaults.object(forKey: documentKey) as? Double) ?? 0
        let synced = (defaults.object(forKey: syncedKey) as? Double) ?? 0
        let floor = max(document, synced, newestEntry?.timeIntervalSince1970 ?? 0)
        defaults.set(max(now.timeIntervalSince1970, floor + 0.001), forKey: documentKey)
    }

    func reconcile<Entry: Identifiable & Equatable>(remote: [Entry], local: [Entry], remoteStamp: Date, now: Date = .now) {
        let remoteById = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard local.contains(where: { remoteById[$0.id] != $0 }) else {
            markPushed(remoteStamp)
            return
        }
        let document = (defaults.object(forKey: documentKey) as? Double) ?? 0
        let next = max(now.timeIntervalSince1970, remoteStamp.timeIntervalSince1970 + 0.001)
        defaults.set(max(document, next), forKey: documentKey)
    }

    private static func rounded(_ date: Date) -> Date {
        Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds(date)) / 1_000)
    }
}
