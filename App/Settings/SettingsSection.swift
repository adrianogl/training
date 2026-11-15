enum SettingsSection: String, CaseIterable, Identifiable {
    case connections, notices, app

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connections: "Conta e conexões"
        case .notices: "Avisos"
        case .app: "App"
        }
    }

    var groups: [SettingsGroup] {
        SettingsGroup.allCases.filter { $0.section == self }
    }
}
