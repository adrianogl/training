public struct SuggestedLoad: Codable, Sendable, Equatable {
    public let weight: Double
    public let baseId: String
    public let baseWeight: Double
    public let baseDay: String?

    public init(weight: Double, baseId: String, baseWeight: Double, baseDay: String?) {
        self.weight = weight
        self.baseId = baseId
        self.baseWeight = baseWeight
        self.baseDay = baseDay
    }
}
