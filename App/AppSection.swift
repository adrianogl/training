import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case evolution
    case workouts
    case races
    case settings

    var id: String { rawValue }

    var path: String {
        switch self {
        case .today: "hoje"
        case .evolution: "evolucao"
        case .workouts: "treinos"
        case .races: "provas"
        case .settings: "ajustes"
        }
    }

    static func initial(defaults: UserDefaults = .standard) -> AppSection {
        #if DEBUG
        let path = defaults.string(forKey: AppConstants.initialSectionDefaultsKey)
        return allCases.first { $0.path == path } ?? .today
        #else
        return .today
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
        case .today: "Hoje"
        case .evolution: "Evolução"
        case .workouts: "Treinos"
        case .races: "Provas"
        case .settings: "Ajustes"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .evolution: "chart.line.uptrend.xyaxis"
        case .workouts: "figure.run"
        case .races: "flag.checkered"
        case .settings: "gearshape"
        }
    }
}
