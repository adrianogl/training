import SwiftUI

enum SettingsGroup: String, CaseIterable, Identifiable, Hashable, Codable {
    case account, garmin, mfit, strava, watch, devices, notice, appearance, data, licenses

    var id: String { rawValue }

    var section: SettingsSection {
        switch self {
        case .account, .garmin, .mfit, .strava, .watch, .devices: .connections
        case .notice: .notices
        case .appearance, .data, .licenses: .app
        }
    }

    var title: String {
        switch self {
        case .account: "Conta"
        case .garmin: "Garmin"
        case .mfit: "MFIT"
        case .strava: "Strava"
        case .devices: "Entre aparelhos"
        case .watch: "Relógio"
        case .notice: "Avisos"
        case .appearance: "Aparência"
        case .data: "Dados locais"
        case .licenses: "Licenças"
        }
    }

    var systemImage: String {
        switch self {
        case .account: "person.crop.circle.fill"
        case .garmin: "triangle.fill"
        case .mfit: "dumbbell.fill"
        case .strava: "figure.run"
        case .devices: "ipad.and.iphone"
        case .watch: "applewatch"
        case .notice: "bell.fill"
        case .appearance: "circle.lefthalf.filled"
        case .data: "internaldrive.fill"
        case .licenses: "doc.text.fill"
        }
    }

    var tint: Color {
        switch self {
        case .account: Color(hex: 0x4E6A00)
        case .garmin: Color(hex: 0x1F7AE0)
        case .mfit: Color(hex: 0xE5484D)
        case .strava: Color(hex: 0xFC4C02)
        case .devices: Color(hex: 0x6E5BD6)
        case .watch: Color(hex: 0x2C2F36)
        case .notice: Color(hex: 0xE0682B)
        case .appearance: Color(hex: 0x5C636C)
        case .data: Color(hex: 0x8A9099)
        case .licenses: Color(hex: 0x3A4350)
        }
    }
}
