import Foundation

enum ScoreCelebration {
    enum Place {
        case row, detail

        var key: String {
            switch self {
            case .row: ScoreConstants.celebratedRowsKey
            case .detail: ScoreConstants.celebratedDetailsKey
            }
        }
    }

    static func claimFirstTime(_ place: Place, activityId: Int64, defaults: UserDefaults = AccountScope.current.defaults) -> Bool {
        var seen = (defaults.array(forKey: place.key) as? [NSNumber])?.map(\.int64Value) ?? []
        guard !seen.contains(activityId) else { return false }
        seen.append(activityId)
        defaults.set(seen.suffix(ScoreConstants.celebrationMemory).map { NSNumber(value: $0) }, forKey: place.key)
        return true
    }
}
