import Foundation

public enum LiveStrengthAction: Codable, Sendable, Equatable {
    case setDone(exerciseId: String, result: LiveStrengthSetResult)
    case adjust(exerciseId: String, setIndex: Int, result: LiveStrengthSetResult)
    case skip(exerciseId: String)
    case doNow(exerciseId: String)
    case leaveOut(exerciseId: String)
    case setWeight(exerciseId: String, weight: Double?, bodyweight: Bool, nextOnly: Bool)
}

public struct LiveStrengthWeightOverride: Codable, Sendable, Equatable {
    public var weight: Double?
    public var bodyweight: Bool
    public var nextOnly: Bool

    public init(weight: Double?, bodyweight: Bool, nextOnly: Bool) {
        self.weight = weight
        self.bodyweight = bodyweight
        self.nextOnly = nextOnly
    }
}

public struct LiveStrengthEvent: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var sequence: Int
    public var action: LiveStrengthAction

    public init(id: String, sequence: Int, action: LiveStrengthAction) {
        self.id = id
        self.sequence = sequence
        self.action = action
    }
}

public struct LiveStrengthSession: Codable, Sendable, Equatable {
    public var plan: LiveStrengthPlan
    public var done: [String: [LiveStrengthSetResult]]
    public var order: [String]
    public var skipped: [String]
    public var leftOut: [String]
    public var events: [LiveStrengthEvent]
    public var overrides: [String: LiveStrengthWeightOverride]?

    public init(plan: LiveStrengthPlan) {
        self.plan = plan
        self.done = [:]
        self.order = plan.blocks.map(\.id)
        self.skipped = []
        self.leftOut = []
        self.events = []
    }
}

public struct LiveStrengthNextSet: Sendable, Equatable {
    public var blockId: String
    public var exerciseId: String
    public var setIndex: Int
    public var round: Int
    public var reps: Int?
    public var seconds: Int?
    public var weight: Double?
}
