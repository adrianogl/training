import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var score: Int?
    var verdict: String?
    var readinessLine: String?
    var workoutTitle: String?
    var workoutDetail: String?
    var strengthTitle: String?
    var raceName: String?
    var raceDays: Int?
    var weekText: String?
    var updatedAt: Date

    static let empty = WidgetSnapshot(updatedAt: .distantPast)
}
