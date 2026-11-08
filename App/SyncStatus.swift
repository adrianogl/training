import Foundation

enum SyncStatus: Equatable {
    case idle
    case running(progress: Double)
    case finished(Date)
    case failed(SyncFailure)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}
