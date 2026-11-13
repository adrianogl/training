import TrainingCore

public struct DatedValue: Sendable, Equatable {
    public var day: Day
    public var value: Double

    public init(day: Day, value: Double) {
        self.day = day
        self.value = value
    }
}

public struct Prediction: Sendable, Equatable {
    public var label: String
    public var seconds: Double?
    public var yearAgoSeconds: Double?

    public init(label: String, seconds: Double?, yearAgoSeconds: Double? = nil) {
        self.label = label
        self.seconds = seconds
        self.yearAgoSeconds = yearAgoSeconds
    }
}

public struct TrainingReport: Sendable, Equatable {
    public var days: Int
    public var activities: Int
    public var today: Day
    public var readinessScore: Int?
    public var readinessPartial: Bool
    public var vo2max: DatedValue?
    public var fitness: Double?
    public var fatigue: Double?
    public var form: Double?
    public var acuteChronic: Double?
    public var predictions: [Prediction]
    public var durability: DatedValue?
    public var hillStrength: DatedValue?
}
