public enum ReadinessComponent: String, CaseIterable, Sendable {
    case hrv, sleep, bodyBattery, load

    var weight: Double {
        switch self {
        case .hrv: ReadinessConstants.hrvWeight
        case .sleep: ReadinessConstants.sleepWeight
        case .bodyBattery: ReadinessConstants.bodyBatteryWeight
        case .load: ReadinessConstants.loadWeight
        }
    }
}

public struct ReadinessFactor: Sendable, Equatable {
    public var component: ReadinessComponent
    public var todayScore: Double?
    public var normalScore: Double?
    public var points: Double?
    public var weight: Double

    public init(component: ReadinessComponent, todayScore: Double?, normalScore: Double?, points: Double?, weight: Double) {
        self.component = component
        self.todayScore = todayScore
        self.normalScore = normalScore
        self.points = points
        self.weight = weight
    }
}

public struct ReadinessBreakdown: Sendable, Equatable {
    public var score: Int
    public var normal: Double?
    public var factors: [ReadinessFactor]

    public init(score: Int, normal: Double?, factors: [ReadinessFactor]) {
        self.score = score
        self.normal = normal
        self.factors = factors
    }
}
