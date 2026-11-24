@MainActor final class WatchPendingActionHandler {
    static let shared = WatchPendingActionHandler()

    var send: (@MainActor () async -> Void)?
}
