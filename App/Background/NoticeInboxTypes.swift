import Foundation

struct NoticeItem: Codable, Equatable, Sendable {
    var id: String
    var title: String?
    var text: String
    var link: String
    var deliverAt: Date
    var dailyHour: Int?
    var readAt: Date?
}

struct NoticeEntry: Equatable, Identifiable, Sendable {
    let id: String
    let title: String?
    let text: String
    let link: String
    let deliveredAt: Date
    let isRead: Bool
}
