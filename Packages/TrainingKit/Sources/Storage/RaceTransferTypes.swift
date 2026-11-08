import Foundation

struct RaceTransferFile: Codable {
    var version: Int
    var races: [RaceTransferItem]
}

struct RaceTransferVersionProbe: Decodable {
    var version: Int
}

struct RaceTransferItem: Codable {
    var id: UUID
    var name: String
    var day: String
    var startTime: String?
    var distance: Double
    var goalSeconds: Double?
    var priority: String
    var city: String?
    var gpxData: Data?
    var manualPacesData: Data?
    var customLabelsData: Data?
    var resultActivityId: Int64?
    var updatedAt: Date
}
