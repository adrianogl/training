import Foundation
import Storage

struct GoalDraft: Equatable {
    var kind: GoalKind = .time
    var distanceKm: Double = 10
    var time = ""
    var hasDeadline = false
    var deadline = Date.now
    var longDistance = ""
    var pace = ""
}

enum GoalDraftError: Error, Equatable {
    case time, distance, pace, deadline
}

struct GoalValues: Equatable {
    var kind: GoalKind
    var distanceKm: Double
    var targetSeconds: Double?
    var deadline: String?
    var paceSecondsPerKm: Double?
}
