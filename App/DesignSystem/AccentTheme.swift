import SwiftUI
import UIKit

enum AccentTheme: String, CaseIterable, Identifiable, Sendable {
    case pista, lilac

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pista: AccentThemeConstants.pistaTitle
        case .lilac: AccentThemeConstants.lilacTitle
        }
    }

    var subtitle: String {
        switch self {
        case .pista: AccentThemeConstants.pistaSubtitle
        case .lilac: AccentThemeConstants.lilacSubtitle
        }
    }

    static func stored(_ raw: String) -> AccentTheme {
        AccentTheme(rawValue: raw) ?? .pista
    }
}

struct AccentThemeTrait: UITraitDefinition {
    static let defaultValue = AccentTheme.pista
    static let affectsColorAppearance = true
}

extension UITraitCollection {
    var accentTheme: AccentTheme { self[AccentThemeTrait.self] }
}

extension UIMutableTraits {
    var accentTheme: AccentTheme {
        get { self[AccentThemeTrait.self] }
        set { self[AccentThemeTrait.self] = newValue }
    }
}

struct AccentThemeKey: UITraitBridgedEnvironmentKey {
    static let defaultValue = AccentTheme.pista

    static func read(from traitCollection: UITraitCollection) -> AccentTheme {
        traitCollection.accentTheme
    }

    static func write(to mutableTraits: inout UIMutableTraits, value: AccentTheme) {
        mutableTraits.accentTheme = value
    }
}

extension EnvironmentValues {
    var accentTheme: AccentTheme {
        get { self[AccentThemeKey.self] }
        set { self[AccentThemeKey.self] = newValue }
    }
}

struct ThemedHex: Sendable {
    let light: UInt32
    let dark: UInt32
    var lightOpacity: Double = 1
    var darkOpacity: Double = 1
}

extension Color {
    init(pista: ThemedHex, lilac: ThemedHex) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.accentTheme == .lilac ? lilac : pista
            return traits.userInterfaceStyle == .light
                ? UIColor(hex: hex.light, alpha: hex.lightOpacity)
                : UIColor(hex: hex.dark, alpha: hex.darkOpacity)
        })
    }
}
