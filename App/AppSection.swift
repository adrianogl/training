import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case workouts
    case settings

    var id: String { rawValue }

    var path: String {
        switch self {
        case .workouts: "treinos"
        case .settings: "ajustes"
        }
    }

    static func initial(defaults: UserDefaults = .standard) -> AppSection {
        #if DEBUG
        let path = defaults.string(forKey: AppConstants.initialSectionDefaultsKey)
        return allCases.first { $0.path == path } ?? .workouts
        #else
        return .workouts
        #endif
    }

    init?(url: URL) {
        guard url.scheme == AppConstants.urlScheme,
              let section = Self.allCases.first(where: { $0.path == url.host() })
        else { return nil }
        self = section
    }

    var title: String {
        switch self {
        case .workouts: "Treinos"
        case .settings: "Ajustes"
        }
    }

    var systemImage: String {
        switch self {
        case .workouts: "figure.run"
        case .settings: "gearshape"
        }
    }
}
