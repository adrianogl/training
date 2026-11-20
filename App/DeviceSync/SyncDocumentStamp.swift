import Foundation
import RemoteSync

struct SyncDocumentStamp {
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

    func noteRemote(stamp: Date, localHasExtra: Bool, now: Date = .now) {
        guard localHasExtra else {
            markPushed(stamp)
            return
        }
        let next = max(now.timeIntervalSince1970, stamp.timeIntervalSince1970 + 0.001)
        let current = (defaults.object(forKey: documentKey) as? Double) ?? 0
        defaults.set(max(current, next), forKey: documentKey)
    }

    private static func rounded(_ date: Date) -> Date {
        Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds(date)) / 1_000)
    }
}
