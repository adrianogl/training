import Foundation
import Metrics
import WorkoutAnalysis

public final class ReportMemo: @unchecked Sendable {
    private let lock = NSLock()
    private var efforts: [[Int64]: [Effort]] = [:]
    private var sessions: [[Int64]: [RunKind: [TrainingSession]]] = [:]
    private var effortRuns = 0
    private var sessionRuns = 0

    public init() {}

    public var effortComputations: Int { locked { effortRuns } }
    public var sessionComputations: Int { locked { sessionRuns } }

    func efforts(for key: [Int64], compute: () throws -> [Effort]) rethrows -> [Effort] {
        if let cached = locked({ efforts[key] }) { return cached }
        let value = try compute()
        locked {
            efforts[key] = value
            effortRuns += 1
        }
        return value
    }

    func sessions(for key: [Int64], compute: () throws -> [RunKind: [TrainingSession]]) rethrows -> [RunKind: [TrainingSession]] {
        if let cached = locked({ sessions[key] }) { return cached }
        let value = try compute()
        locked {
            sessions[key] = value
            sessionRuns += 1
        }
        return value
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
