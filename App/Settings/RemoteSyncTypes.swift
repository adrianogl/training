import Foundation

enum RemoteSyncProblem: Equatable, Sendable {
    case keyNotFound
    case busy
    case quotaExceeded
    case unreadable
    case other
}

enum RemoteSyncStatus: Equatable, Sendable {
    case off
    case idle
    case syncing
    case waitingForNetwork(pending: Int)
    case failed(RemoteSyncProblem)
}

enum RemoteSyncChip: Equatable, Sendable {
    case waiting(String)
    case failed(String)

    var text: String {
        switch self {
        case .waiting(let text), .failed(let text): text
        }
    }
}

struct RemoteSyncCounts: Equatable, Sendable {
    let races: Int
    let decisions: Int
}

enum DeviceOwnerResult: Equatable, Sendable {
    case granted
    case denied
    case unavailable
}

protocol DeviceOwnerAuthenticating: Sendable {
    func authenticate(reason: String) async -> DeviceOwnerResult
}

protocol KeyClipboard: Sendable {
    func copy(_ key: String)
}

enum RemoteSyncPart {
    case sync
    case watch
}
