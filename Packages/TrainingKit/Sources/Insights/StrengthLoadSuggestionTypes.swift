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

public enum SuggestionStepKind: String, Sendable, Equatable {
    case unilateral, perHand, firstTime
}

public struct SuggestionStep: Sendable, Equatable {
    public let kind: SuggestionStepKind
    public let share: Double
    public let weight: Double
}
