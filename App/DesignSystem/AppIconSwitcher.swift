import UIKit

@MainActor
enum AppIconSwitcher {
    static func iconName(for theme: AccentTheme, style: AppIconStyle) -> String? {
        switch (theme, style) {
        case (.pista, .system): nil
        case (.pista, .light): AppIconConstants.pistaLightName
        case (.pista, .dark): AppIconConstants.pistaDarkName
        case (.lilac, .system): AppIconConstants.lilacName
        case (.lilac, .light): AppIconConstants.lilacLightName
        case (.lilac, .dark): AppIconConstants.lilacDarkName
        }
    }

    static func previewNames(for theme: AccentTheme) -> (light: String, dark: String) {
        switch theme {
        case .pista: (AppIconConstants.pistaLightPreview, AppIconConstants.pistaDarkPreview)
        case .lilac: (AppIconConstants.lilacLightPreview, AppIconConstants.lilacDarkPreview)
        }
    }

    static func apply(_ theme: AccentTheme, style: AppIconStyle) {
        let application = UIApplication.shared
        let wanted = iconName(for: theme, style: style)
        guard application.supportsAlternateIcons, application.alternateIconName != wanted else { return }
        Task { try? await application.setAlternateIconName(wanted) }
    }
}
