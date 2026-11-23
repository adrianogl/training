import Foundation

enum WatchLinkRecordKind: String, Codable, Sendable {
    case devices
    case started
    case status
    case events
    case pong
    case sent
    case failure
}

struct WatchLinkRecord: Codable, Sendable {
    var at: Date
    var appState: String
    var kind: WatchLinkRecordKind
    var detail: String
    var eventIds: [String] = []
    var delaySeconds: [Double] = []
    var roundTripMs: Int?
}
