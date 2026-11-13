import Foundation

struct RaceTransferFile: Codable {
    var version: Int
    var races: [RaceTransferItem]
}

struct RaceTransferVersionProbe: Decodable {
    var version: Int
}

public struct RaceTransferItem: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var day: String
    public var startTime: String?
    public var distance: Double
    public var goalSeconds: Double?
    public var priority: String
    public var city: String?
    public var gpxData: Data?
    public var manualPacesData: Data?
    public var customLabelsData: Data?
    public var resultActivityId: Int64?
    public var frozenTargetSeconds: Double?
    public var frozenTargetDay: String?
    public var manuallyUnlinked: Bool?
    public var updatedAt: Date
}
