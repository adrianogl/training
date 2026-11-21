import Foundation
import TrainingCore

public enum StrengthObjective: String, Codable, Sendable, CaseIterable {
    case mobility
    case strength
    case prevention
    case performance
    case maintenance
}

public enum StrengthPlanValidity: Codable, Sendable, Equatable {
    case untilRace(raceId: String, raceDay: Day)
    case weeks(Int)
    case untilDate(Day)
}

public enum StrengthPlanBuilder: String, Codable, Sendable {
    case trainer
    case claude
}
