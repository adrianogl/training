import Foundation

enum ConnectionStatus: Equatable {
    case untested
    case testing
    case connected(Date)
    case failed(SyncFailure)
}
