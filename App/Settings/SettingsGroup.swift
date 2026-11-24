import SwiftUI

enum SettingsGroup: String, CaseIterable, Identifiable, Hashable, Codable {
    case account, invites, device, garmin, mfit, strava, watch, claude, notice, appearance, data, licenses

    var id: String { rawValue }

    var section: SettingsSection {
        switch self {
        case .account, .invites: .account
        case .device, .garmin, .mfit, .strava, .watch, .claude: .connections
        case .notice, .appearance, .data, .licenses: .app
        }
    }

    var title: String {
        switch self {
        case .account: "Conta"
        case .invites: InvitesConstants.title
        case .device: WatchKindConstants.settingsTitle
        case .garmin: "Garmin"
        case .mfit: "MFIT"
        case .strava: "Strava"
        case .watch: "Mostrador"
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
        case .device: "applewatch.side.right"
        case .garmin: "triangle.fill"
        case .mfit: "dumbbell.fill"
        case .strava: "figure.run"
        case .watch: "clock.fill"
        case .claude: "sparkles"
        case .notice: "bell.fill"
        case .appearance: "circle.lefthalf.filled"
        case .data: "internaldrive.fill"
        case .licenses: "doc.text.fill"
        }
    }

    var brandTint: Color? {
        switch self {
        case .garmin: Color(hex: 0x1F7AE0)
        case .mfit: Color(hex: 0xE5484D)
        case .strava: Color(hex: 0xFC4C02)
        case .claude: Color(hex: 0xD97757)
        default: nil
        }
    }
}
