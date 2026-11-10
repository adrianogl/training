import Foundation

protocol NotificationScheduling: Sendable {
    func pending() async -> [String]
    func schedule(id: String, text: String, at: Date?) async
    func cancel(id: String) async
}

struct MorningNoticeSettings: Equatable, Sendable {
    var enabled: Bool
    var minimumMinutes: Int
}
