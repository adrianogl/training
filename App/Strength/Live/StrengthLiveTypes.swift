import Foundation
import Insights

struct StrengthLiveSnapshot: Codable, Sendable {
    var startedAt: Date
    var session: LiveStrengthSession
    var status: LiveStrengthWatchStatus?
}
