import SwiftUI

enum SettingsGroup: String, CaseIterable, Identifiable, Hashable {
    case garmin, devices, watch, notice, goals, appearance, data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .garmin: "Garmin"
        case .devices: "Entre aparelhos"
        case .watch: "Relógio"
        case .notice: "Aviso de manhã"
        case .goals: "Metas"
        case .appearance: "Aparência"
        case .data: "Dados locais"
        }
    }

    var systemImage: String {
        switch self {
        case .garmin: "triangle.fill"
        case .devices: "ipad.and.iphone"
        case .watch: "applewatch"
        case .notice: "bell.fill"
        case .goals: "target"
        case .appearance: "circle.lefthalf.filled"
        case .data: "internaldrive.fill"
        }
    }

    var tint: Color {
        switch self {
        case .garmin: Color(hex: 0x1F7AE0)
        case .devices: Color(hex: 0x6E5BD6)
        case .watch: Color(hex: 0x2C2F36)
        case .notice: Color(hex: 0xE0682B)
        case .goals: Color(hex: 0x4E8F1C)
        case .appearance: Color(hex: 0x5C636C)
        case .data: Color(hex: 0x8A9099)
        }
    }
}
