import UIKit

@MainActor
enum AppIconSwitcher {
    static func iconName(for theme: AccentTheme) -> String? {
        switch theme {
        case .pista: nil
        case .lilac: AccentThemeConstants.lilacIconName
        }
    }

    static func apply(_ theme: AccentTheme) {
        let application = UIApplication.shared
        let wanted = iconName(for: theme)
        guard application.supportsAlternateIcons, application.alternateIconName != wanted else { return }
        Task { try? await application.setAlternateIconName(wanted) }
    }
}
