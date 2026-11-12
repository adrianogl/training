import TrainingCore

public struct RaceCandidate: Sendable, Identifiable, Equatable {
    public var activityId: Int64
    public var day: Day
    public var name: String
    public var distance: Double
    public var seconds: Double
    public var averageHeartRate: Int?
    public var isPR: Bool

    public var id: Int64 { activityId }

    public init(activityId: Int64, day: Day, name: String, distance: Double, seconds: Double, averageHeartRate: Int?, isPR: Bool) {
        self.activityId = activityId
        self.day = day
        self.name = name
        self.distance = distance
        self.seconds = seconds
        self.averageHeartRate = averageHeartRate
        self.isPR = isPR
    }
}
