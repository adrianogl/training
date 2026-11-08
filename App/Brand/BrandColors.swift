import SwiftUI

enum BrandColors {
    static let background = Color(hex: 0x07080A)
    static let accent = Color(hex: 0xC8F05A)
    static let onAccent = Color(hex: 0x0B0D10)
    static let text = Color(hex: 0xEDEFF2)
    static let dim = Color(hex: 0x8A9099)
    static let line = Color.white.opacity(0.10)
    static let iconBase = Color(hex: 0x0B0E12)
    static let shareTop = Color(hex: 0x10141A)
    static let checkerLight = Color(hex: 0x2A2D33)
    static let checkerDark = Color(hex: 0x1D2025)
    static let stickerLabel = Color.white.opacity(0.78)
    static let stickerShadow = Color.black.opacity(0.55)
    static let race = Color(hex: 0xFF8A4C)
    static let danger = Color(hex: 0xFF5A5A)
    static let accentGlow = accent.opacity(0.10)
    static let raceGlow = race.opacity(0.08)
    static let attention = Color(hex: 0xFFC24C)
    static let neutralBar = Color.white.opacity(0.35)
    static let track = Color.white.opacity(0.06)
    static let band = Color.white.opacity(0.45)
    static let zones = [
        Color(hex: 0x5AA9F0),
        Color(hex: 0x5AF0B4),
        Color(hex: 0xC8F05A),
        Color(hex: 0xFFC24C),
        Color(hex: 0xFF6A4C),
    ]

    static func zone(_ number: Int?) -> Color {
        guard let number, zones.indices.contains(number - 1) else { return neutralBar }
        return zones[number - 1]
    }
}
