import SwiftUI

enum BrandColors {
    static let background = Color(light: 0xF3F4F0, dark: 0x0D1014)
    static let sidebar = Color(light: 0xEAECE6, dark: 0x141920)
    static let card = Color(light: 0xFFFFFF, dark: 0x181E26)
    static let cardBorder = Color(light: 0x14181C, dark: 0xFFFFFF, lightOpacity: 0.08, darkOpacity: 0.10)
    static let accent = Color(pista: ThemedHex(light: 0x4E6A00, dark: 0xC8F05A), lilac: ThemedHex(light: 0x6237C2, dark: 0xC9A8FF))
    static let accentFill = Color(pista: ThemedHex(light: 0x9CC421, dark: 0xC8F05A), lilac: ThemedHex(light: 0xA88AF2, dark: 0xC9A8FF))
    static let onAccent = Color(pista: ThemedHex(light: 0x0D1014, dark: 0x0D1014), lilac: ThemedHex(light: 0x130D1F, dark: 0x130D1F))
    static let ready = Color(light: 0x4E6A00, dark: 0xC8F05A)
    static let readyFill = Color(light: 0x9CC421, dark: 0xC8F05A)
    static let text = Color(light: 0x14181C, dark: 0xE8ECEF)
    static let dim = Color(light: 0x5C636C, dark: 0x8A949F)
    static let line = Color(light: 0x14181C, dark: 0xFFFFFF, lightOpacity: 0.09, darkOpacity: 0.10)
    static let iconBase = Color(hex: 0x0B0E12)
    static let iconAccent = Color(pista: ThemedHex(light: 0xC8F05A, dark: 0xC8F05A), lilac: ThemedHex(light: 0xC9A8FF, dark: 0xC9A8FF))
    static let iconRunner = Color(hex: 0xEDEFF2)
    static let loaderFill = Color(pista: ThemedHex(light: 0x1A2410, dark: 0x1A2410), lilac: ThemedHex(light: 0x1D1430, dark: 0x1D1430))
    static let loaderEdge = Color(pista: ThemedHex(light: 0x3C5214, dark: 0x3C5214), lilac: ThemedHex(light: 0x4A3478, dark: 0x4A3478))
    static let shareTop = Color(hex: 0x10141A)
    static let checkerLight = Color(hex: 0x2A2D33)
    static let checkerDark = Color(hex: 0x1D2025)
    static let stickerLabel = Color.white.opacity(0.78)
    static let stickerShadow = Color.black.opacity(0.55)
    static let race = Color(light: 0xD45A1E, dark: 0xFF8A4C)
    static let danger = Color(light: 0xCC3B33, dark: 0xFF5A5A)
    static let accentGlow = Color(pista: ThemedHex(light: 0x9CC421, dark: 0xC8F05A, lightOpacity: 0.14, darkOpacity: 0.10), lilac: ThemedHex(light: 0xA88AF2, dark: 0xC9A8FF, lightOpacity: 0.16, darkOpacity: 0.12))
    static let raceGlow = Color(light: 0xD45A1E, dark: 0xFF8A4C, lightOpacity: 0.07, darkOpacity: 0.08)
    static let attention = Color(light: 0xB87A00, dark: 0xFFC24C)
    static let record = Color(light: 0x8F6A00, dark: 0xFFD45C)
    static let recordFill = Color(light: 0xE8B931, dark: 0xFFD45C)
    static let recordGlow = Color(light: 0xE8B931, dark: 0xFFD45C, lightOpacity: 0.14, darkOpacity: 0.12)
    static let fitness = Color(light: 0x2F6FD6, dark: 0x7FB2FF)
    static let form = Color(light: 0xA27F00, dark: 0xE8C547)
    static let rest = Color(light: 0xCC3B33, dark: 0xE5534B)
    static let strength = Color(pista: ThemedHex(light: 0x7B5CD6, dark: 0xB59CFF), lilac: ThemedHex(light: 0x0E8C7E, dark: 0x5FD3C4))
    static let strengthGlow = Color(pista: ThemedHex(light: 0x7B5CD6, dark: 0xB59CFF, lightOpacity: 0.15, darkOpacity: 0.15), lilac: ThemedHex(light: 0x0E8C7E, dark: 0x5FD3C4, lightOpacity: 0.15, darkOpacity: 0.15))
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
