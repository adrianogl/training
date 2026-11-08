import TrainingCore

public enum EffortKind: String, Codable, Sendable {
    case race, split5k, split1k
}

public struct Effort: Codable, Sendable, Equatable {
    public var distance: Double
    public var seconds: Double
    public var day: Day
    public var kind: EffortKind

    public init(distance: Double, seconds: Double, day: Day, kind: EffortKind) {
        self.distance = distance
        self.seconds = seconds
        self.day = day
        self.kind = kind
    }
}

public enum GoalAssessment: String, Codable, Sendable {
    case easy, challenging, aggressive
}

public struct KmPlan: Codable, Sendable, Equatable {
    public var index: Int
    public var pace: Double
    public var grade: Double
    public var label: String
    public var manual: Bool

    public init(index: Int, pace: Double, grade: Double, label: String, manual: Bool) {
        self.index = index
        self.pace = pace
        self.grade = grade
        self.label = label
        self.manual = manual
    }
}

public struct BlockWeek: Sendable, Equatable {
    public var start: Day
    public var km: Double
    public var projected: Bool

    public init(start: Day, km: Double, projected: Bool) {
        self.start = start
        self.km = km
        self.projected = projected
    }
}
