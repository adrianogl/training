import Synchronization

final class ProgressRecorder: Sendable {
    private let storage = Mutex<[Double]>([])

    var values: [Double] { storage.withLock { $0 } }

    func record(_ value: Double) {
        storage.withLock { $0.append(value) }
    }
}
