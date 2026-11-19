import Foundation

protocol NotificationScheduling: Sendable {
    func pending() async -> [String]
    func schedule(id: String, text: String, at: Date?) async
    func schedule(id: String, title: String?, text: String, link: String, at: Date?) async
    func scheduleDaily(id: String, title: String, text: String, link: String, hour: Int) async
    func cancel(id: String) async
}

struct MorningNoticeSettings: Equatable, Sendable {
    var enabled: Bool
    var minimumMinutes: Int
}

struct WorkoutGoalNotice: Equatable {
    var metGoal: String?
    var note: String?
}
