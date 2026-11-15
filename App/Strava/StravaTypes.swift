import Foundation

enum StravaPhase: Equatable {
    case idle, working
}

enum StravaSendResult: Equatable, Sendable {
    case posted, updated, notYet, editedByUser, disabled, notConnected, retryLater, failed, noText

    var message: String {
        switch self {
        case .posted: StravaConstants.sent
        case .updated: StravaConstants.updated
        case .notYet: StravaConstants.notYet
        case .editedByUser: StravaConstants.editedByUser
        case .disabled: StravaConstants.disabled
        case .notConnected: StravaConstants.notConnected
        case .retryLater: StravaConstants.retryLater
        case .failed: StravaConstants.sendFailed
        case .noText: StravaConstants.noText
        }
    }

    var isSuccess: Bool { self == .posted || self == .updated }
}

protocol StravaWebAuthenticating {
    @MainActor func authenticate(url: URL) async throws -> URL
}
