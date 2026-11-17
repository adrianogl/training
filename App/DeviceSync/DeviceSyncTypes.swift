import Foundation

struct PreferenceSyncEntry: Codable, Equatable {
    var digest: String
    var updatedAt: Date
    var pending: Bool
}

struct ChatFolder: Sendable {
    let tag: String
    let url: URL
}
