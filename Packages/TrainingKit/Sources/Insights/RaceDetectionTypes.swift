import Foundation
import TrainingCore

public struct RaceCandidate: Sendable, Identifiable, Equatable, Codable {
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

public struct RaceTarget: Sendable, Equatable, Codable {
    public var id: UUID
    public var distance: Double
    public var targetSeconds: Double?
    public var strategyPaces: [Int: Double]

    public init(id: UUID = UUID(), distance: Double, targetSeconds: Double? = nil, strategyPaces: [Int: Double] = [:]) {
        self.id = id
        self.distance = distance
        self.targetSeconds = targetSeconds
        self.strategyPaces = strategyPaces
    }
}

public struct RaceIndex: Sendable, Equatable {
    public var results: [Int64: RaceTarget]
    public var pending: [Day: [RaceTarget]]

    public init(results: [Int64: RaceTarget] = [:], pending: [Day: [RaceTarget]] = [:]) {
        self.results = results
        self.pending = pending
    }
}
