enum AppIconStyle: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: AppIconConstants.systemTitle
        case .light: AppIconConstants.lightTitle
        case .dark: AppIconConstants.darkTitle
        }
    }

    var subtitle: String {
        switch self {
        case .system: AppIconConstants.systemSubtitle
        case .light: AppIconConstants.lightSubtitle
        case .dark: AppIconConstants.darkSubtitle
        }
    }

    static func stored(_ raw: String) -> AppIconStyle {
        AppIconStyle(rawValue: raw) ?? .system
    }
}
