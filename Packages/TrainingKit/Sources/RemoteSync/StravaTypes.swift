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
    case retryLater
    case server(status: Int)
}

public struct StravaRunCandidate: Equatable, Sendable, Identifiable, Codable {
    public let id: Int64
    public let name: String
    public let sportType: String
    public let start: Date
    public let startLocal: String
    public let distanceMeters: Double
    public let movingSeconds: Double
    public let elapsedSeconds: Double
    public let elevationGain: Double?
    public let averageHeartRate: Double?
    public let maxHeartRate: Double?
    public let hasGps: Bool

    public init(
        id: Int64, name: String, sportType: String, start: Date, startLocal: String, distanceMeters: Double, movingSeconds: Double,
        elapsedSeconds: Double, elevationGain: Double?, averageHeartRate: Double?, maxHeartRate: Double?, hasGps: Bool
    ) {
        self.id = id
        self.name = name
        self.sportType = sportType
        self.start = start
        self.startLocal = startLocal
        self.distanceMeters = distanceMeters
        self.movingSeconds = movingSeconds
        self.elapsedSeconds = elapsedSeconds
        self.elevationGain = elevationGain
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.hasGps = hasGps
    }

    public var localDayISO: String { String(startLocal.prefix(10)) }
}

public struct StravaStreams: Decodable, Equatable, Sendable {
    public let time: [Double]
    public let distance: [Double]
    public let latlng: [[Double]]
    public let altitude: [Double]
    public let heartrate: [Double]
    public let cadence: [Double]
    public let velocity: [Double]

    public init(
        time: [Double], distance: [Double] = [], latlng: [[Double]] = [], altitude: [Double] = [], heartrate: [Double] = [],
        cadence: [Double] = [], velocity: [Double] = []
    ) {
        self.time = time
        self.distance = distance
        self.latlng = latlng
        self.altitude = altitude
        self.heartrate = heartrate
        self.cadence = cadence
        self.velocity = velocity
    }
}

struct StravaStreamsBody: Decodable {
    let streams: StravaStreams?
    let status: String?
}

struct StravaRunsBody: Decodable {
    struct Run: Decodable {
        let id: Int64
        let name: String
        let sportType: String
        let startDate: String
        let startDateLocal: String
        let distanceMeters: Double
        let movingSeconds: Double
        let elapsedSeconds: Double
        let elevationGain: Double?
        let averageHeartRate: Double?
        let maxHeartRate: Double?
        let hasGps: Bool
    }

    let runs: [Run]?
    let status: String?
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
