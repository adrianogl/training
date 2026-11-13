import SwiftUI

enum BrandColors {
    static let background = Color(light: 0xF3F4F0, dark: 0x07080A)
    static let sidebar = Color(light: 0xEAECE6, dark: 0x0B0D10)
    static let card = Color(light: 0xFFFFFF, dark: 0xFFFFFF, lightOpacity: 1, darkOpacity: 0.05)
    static let cardBorder = Color(light: 0x14181C, dark: 0xFFFFFF, lightOpacity: 0.08, darkOpacity: 0.10)
    static let accent = Color(light: 0x4E6A00, dark: 0xC8F05A)
    static let accentFill = Color(light: 0x9CC421, dark: 0xC8F05A)
    static let onAccent = Color(light: 0x0B0D10, dark: 0x0B0D10)
    static let text = Color(light: 0x14181C, dark: 0xEDEFF2)
    static let dim = Color(light: 0x5C636C, dark: 0x8A9099)
    static let line = Color(light: 0x14181C, dark: 0xFFFFFF, lightOpacity: 0.09, darkOpacity: 0.10)
    static let iconBase = Color(hex: 0x0B0E12)
    static let iconAccent = Color(hex: 0xC8F05A)
    static let shareTop = Color(hex: 0x10141A)
    static let checkerLight = Color(hex: 0x2A2D33)
    static let checkerDark = Color(hex: 0x1D2025)
    static let stickerLabel = Color.white.opacity(0.78)
    static let stickerShadow = Color.black.opacity(0.55)
    static let race = Color(light: 0xD45A1E, dark: 0xFF8A4C)
    static let danger = Color(light: 0xCC3B33, dark: 0xFF5A5A)
    static let accentGlow = Color(light: 0x9CC421, dark: 0xC8F05A, lightOpacity: 0.14, darkOpacity: 0.10)
    static let raceGlow = Color(light: 0xD45A1E, dark: 0xFF8A4C, lightOpacity: 0.07, darkOpacity: 0.08)
    static let attention = Color(light: 0xB87A00, dark: 0xFFC24C)
    static let fitness = Color(light: 0x2F6FD6, dark: 0x7FB2FF)
    static let form = Color(light: 0xA27F00, dark: 0xE8C547)
    static let rest = Color(light: 0xCC3B33, dark: 0xE5534B)
    static let marker = Color(light: 0x14181C, dark: 0xFFFFFF, lightOpacity: 0.35, darkOpacity: 0.35)
    static let neutralBar = Color(light: 0x14181C, dark: 0xFFFFFF, lightOpacity: 0.30, darkOpacity: 0.35)
    static let track = Color(light: 0x14181C, dark: 0xFFFFFF, lightOpacity: 0.07, darkOpacity: 0.06)
    static let band = Color(light: 0x14181C, dark: 0xFFFFFF, lightOpacity: 0.40, darkOpacity: 0.45)
    static let zones = [
        Color(light: 0x2F80D0, dark: 0x5AA9F0),
        Color(light: 0x1FAF7A, dark: 0x5AF0B4),
        Color(light: 0x9CC421, dark: 0xC8F05A),
        Color(light: 0xE0A21A, dark: 0xFFC24C),
        Color(light: 0xE0502F, dark: 0xFF6A4C),
    ]

    static func zone(_ number: Int?) -> Color {
        guard let number, zones.indices.contains(number - 1) else { return neutralBar }
        return zones[number - 1]
    }
}
