import FITReader
import Foundation
import Storage

public enum SampleStore {
    public static func samples(_ record: ActivityRecord) -> [FITSample] {
        guard let data = record.samplesData else { return [] }
        let key = SampleCacheKey(activityId: record.activityId, version: record.processingVersion, size: data.count)
        if let cached = SampleCache.shared.value(for: key) { return cached }
        let samples = FITSampleCoding.decode(data) ?? []
        SampleCache.shared.store(samples, for: key)
        return samples
    }
}

struct SampleCacheKey: Hashable {
    let activityId: Int64
    let version: Int
    let size: Int
}

final class SampleCache: @unchecked Sendable {
    static let shared = SampleCache()
    private let lock = NSLock()
    private var entries: [SampleCacheKey: [FITSample]] = [:]
    private var order: [SampleCacheKey] = []

    func value(for key: SampleCacheKey) -> [FITSample]? {
        lock.withLock { entries[key] }
    }

    func store(_ samples: [FITSample], for key: SampleCacheKey) {
        lock.withLock {
            if entries[key] == nil { order.append(key) }
            entries[key] = samples
            while order.count > SampleStoreConstants.capacity {
                entries[order.removeFirst()] = nil
            }
        }
    }
}
