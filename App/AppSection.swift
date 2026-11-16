import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable, Codable {
    case today
    case evolution
    case workouts
    case races
    case trainer
    case settings
    case more

    var id: String { rawValue }

    var path: String {
        switch self {
        case .today: "hoje"
        case .evolution: "evolucao"
        case .workouts: "treinos"
        case .races: "provas"
        case .trainer: "treinador"
        case .settings: "ajustes"
        case .more: "mais"
        }
    }

    static func debugOverride(defaults: UserDefaults = .standard) -> AppSection? {
        #if DEBUG
        let path = defaults.string(forKey: AppConstants.initialSectionDefaultsKey)
        return allCases.first { $0.path == path }
        #else
        return nil
        #endif
    }

    init?(url: URL) {
        guard url.scheme == AppConstants.urlScheme,
              let section = Self.allCases.first(where: { $0.path == url.host() })
        else { return nil }
        self = section
    }

    var isInMore: Bool { AppConstants.moreItems.contains(self) }

    static var sidebarSections: [AppSection] { allCases.filter { $0 != .more } }

    var title: String {
        switch self {
        case .today: "Hoje"
        case .evolution: "Evolução"
        case .workouts: "Treinos"
        case .races: "Provas"
        case .trainer: "Treinador"
        case .settings: "Ajustes"
        case .more: "Mais"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .evolution: "chart.line.uptrend.xyaxis"
        case .workouts: "list.bullet.clipboard"
        case .races: "flag.checkered"
        case .trainer: "figure.run.square.stack"
        case .settings: "gearshape"
        case .more: "ellipsis"
        }
    }
}
