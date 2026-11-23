import ActivityKit
import Foundation

enum StrengthLiveMoment: String, Codable, Hashable {
    case doing, resting, restOver, paused, finished
}

struct StrengthLiveAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var moment: StrengthLiveMoment
        var setsDone: Int
        var setsTotal: Int
        var heartRate: Int?
        var exerciseName: String?
        var shortName: String?
        var setNumber: Int
        var setCount: Int
        var exerciseSetsDone: Int
        var target: String?
        var last: String?
        var lastDone: String?
        var restEndsAt: Date?
        var restSeconds: Int?
    }

    var title: String
}
