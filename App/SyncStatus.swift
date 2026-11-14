import Foundation

struct SyncDataToken: Equatable {
    let finished: Date?
    let deferredFITRevision: Int
}

enum SyncStatus: Equatable {
    case idle
    case running(progress: Double)
    case finished(Date)
    case failed(SyncFailure)

    var isFinished: Bool {
        if case .finished = self { return true }
        return false
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}
