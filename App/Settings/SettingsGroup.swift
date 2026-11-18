import SwiftUI

enum SettingsGroup: String, CaseIterable, Identifiable, Hashable, Codable {
    case account, invites, garmin, mfit, strava, watch, claude, notice, appearance, data, licenses

    var id: String { rawValue }

    var section: SettingsSection {
        switch self {
        case .account, .invites, .garmin, .mfit, .strava, .watch, .claude: .connections
        case .notice: .notices
        case .appearance, .data, .licenses: .app
        }
    }

    var title: String {
        switch self {
        case .account: "Conta"
        case .invites: InvitesConstants.title
        case .garmin: "Garmin"
        case .mfit: "MFIT"
        case .strava: "Strava"
        case .watch: "Relógio"
        case .claude: "Claude"
        case .notice: "Avisos"
        case .appearance: "Aparência"
        case .data: "Dados locais"
        case .licenses: "Licenças"
        }
    }

    var systemImage: String {
        switch self {
        case .account: "person.crop.circle.fill"
        case .invites: "envelope.open.fill"
        case .garmin: "triangle.fill"
        case .mfit: "dumbbell.fill"
        case .strava: "figure.run"
        case .watch: "applewatch"
        case .claude: "sparkles"
        case .notice: "bell.fill"
        case .appearance: "circle.lefthalf.filled"
        case .data: "internaldrive.fill"
        case .licenses: "doc.text.fill"
        }
    }

    var tint: Color {
        switch self {
        case .account: Color(hex: 0x4E6A00)
        case .invites: Color(hex: 0x6B7F2A)
        case .garmin: Color(hex: 0x1F7AE0)
        case .mfit: Color(hex: 0xE5484D)
        case .strava: Color(hex: 0xFC4C02)
        case .watch: Color(hex: 0x2C2F36)
        case .claude: Color(hex: 0xD97757)
        case .notice: Color(hex: 0xE0682B)
        case .appearance: Color(hex: 0x5C636C)
        case .data: Color(hex: 0x8A9099)
        case .licenses: Color(hex: 0x3A4350)
        }
    }
}
