enum SettingsSection: String, CaseIterable, Identifiable {
    case account, connections, app

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: "Conta"
        case .connections: "Conexões"
        case .app: "App"
        }
    }

    var groups: [SettingsGroup] {
        SettingsGroup.allCases.filter { $0.section == self }
    }
}
