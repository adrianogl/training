import Foundation

@MainActor final class StravaNotificationHandler {
    static let shared = StravaNotificationHandler()

    var handle: (@MainActor (String, Int64) async -> Void)?
}
