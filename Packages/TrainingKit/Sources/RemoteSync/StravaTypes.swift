import Foundation

public struct StravaStatus: Equatable, Sendable {
    public var connected: Bool
    public var athleteName: String
    public var format: String
    public var enabled: Bool

    public init(connected: Bool, athleteName: String, format: String, enabled: Bool) {
        self.connected = connected
        self.athleteName = athleteName
        self.format = format
        self.enabled = enabled
    }

    public static let disconnected = StravaStatus(connected: false, athleteName: "", format: "B", enabled: false)
}

public enum StravaDescribeOutcome: String, Equatable, Sendable {
    case posted
    case updated
    case notFound = "not_found"
    case editedByUser = "edited_by_user"
    case disabled
    case retryLater = "retry_later"
}

public struct StravaDescribeRequest: Equatable, Sendable {
    public var activityId: String
    public var startTime: Date
    public var elapsedSeconds: Double
    public var distanceMeters: Double
    public var text: String

    public init(activityId: String, startTime: Date, elapsedSeconds: Double, distanceMeters: Double, text: String) {
        self.activityId = activityId
        self.startTime = startTime
        self.elapsedSeconds = elapsedSeconds
        self.distanceMeters = distanceMeters
        self.text = text
    }
}

public enum StravaLinkError: Error, Equatable {
    case notConfigured
    case notConnected
    case sessionExpired
    case unavailable
    case unauthorized
    case server(status: Int)
}

struct StravaStatusBody: Decodable {
    var connected: Bool
    var athleteName: String?
    var format: String?
    var enabled: Bool?
}

struct StravaConnectBody: Decodable {
    var url: URL
}

struct StravaDescribeBody: Decodable {
    var status: String
}

struct StravaErrorBody: Decodable {
    var error: String
}
