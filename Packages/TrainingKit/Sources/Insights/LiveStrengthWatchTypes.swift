import Foundation

public struct LiveStrengthLoadHistory: Sendable, Equatable {
    public var key: String
    public var day: String
    public var loads: [Double]

    public init(key: String, day: String, loads: [Double]) {
        self.key = key
        self.day = day
        self.loads = loads
    }
}

struct LiveStrengthWatchMessage: Codable, Equatable {
    var plans: [LiveStrengthWatchPlan]
}

struct LiveStrengthWatchPlan: Codable, Equatable {
    var day: String
    var title: String
    var blocks: [LiveStrengthWatchBlock]
}

struct LiveStrengthWatchBlock: Codable, Equatable {
    var id: String
    var rounds: Int
    var restSeconds: Int
    var exercises: [LiveStrengthWatchExercise]
}

struct LiveStrengthWatchExercise: Codable, Equatable {
    var id: String
    var name: String
    var kind: LiveStrengthSetKind
    var reps: Int?
    var seconds: Int?
    var weight: Double?
    var bodyweight: Bool
    var perSide: Bool
    var last: [LiveStrengthWatchLast]
}

struct LiveStrengthWatchLast: Codable, Equatable {
    var reps: Int?
    var seconds: Int?
    var weight: Double?
}
