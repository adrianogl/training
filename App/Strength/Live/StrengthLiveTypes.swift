import Foundation
import Insights

enum StrengthLiveCommand: String, Sendable {
    case skip, doNow
}

struct StrengthLivePendingCommand: Equatable, Sendable {
    var kind: StrengthLiveCommand
    var exerciseId: String
    var sentAt: Date
}

enum StrengthLiveUploadState: String, Codable, Sendable {
    case pending, sent, alreadyHadSets, notFound, failed
}

struct StrengthLiveFinish: Codable, Sendable {
    var at: Date
    var saved: Bool
    var durationSeconds: Double
    var averageHeartRate: Int?
    var activityId: Int64?
    var upload: StrengthLiveUploadState
}

struct StrengthLiveSnapshot: Codable, Sendable {
    var startedAt: Date
    var session: LiveStrengthSession
    var status: LiveStrengthWatchStatus?
    var finish: StrengthLiveFinish?
}
