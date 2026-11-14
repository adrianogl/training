public struct GarminReadinessScore: Codable, Equatable, Sendable {
    public var day: String
    public var score: Int

    public init(day: String, score: Int) {
        self.day = day
        self.score = score
    }
}

struct GarminReadinessDTO: Decodable {
    var calendarDate: String?
    var score: Int?
    var timestamp: String?
}
