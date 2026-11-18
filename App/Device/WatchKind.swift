import Foundation

enum WatchKind: String, CaseIterable, Identifiable, Sendable {
    case garmin, appleWatch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .garmin: WatchKindConstants.garminTitle
        case .appleWatch: WatchKindConstants.appleTitle
        }
    }

    var detail: String {
        switch self {
        case .garmin: WatchKindConstants.garminDetail
        case .appleWatch: WatchKindConstants.appleDetail
        }
    }

    var symbol: String {
        switch self {
        case .garmin: "circle.circle"
        case .appleWatch: "applewatch"
        }
    }

    var usesGarmin: Bool { self == .garmin }

    static func stored(in defaults: UserDefaults) -> WatchKind? {
        defaults.string(forKey: WatchKindConstants.defaultsKey).flatMap(WatchKind.init(rawValue:))
    }

    func store(in defaults: UserDefaults) {
        defaults.set(rawValue, forKey: WatchKindConstants.defaultsKey)
    }
}
