import Foundation
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct AccentThemeTests {
    @Test func storedFallsBackToPista() {
        #expect(AccentTheme.stored("lilac") == .lilac)
        #expect(AccentTheme.stored("rosa") == .pista)
        #expect(AccentTheme.stored("") == .pista)
    }

    @Test func accentResolvesPerTheme() {
        let pista = UIColor(BrandColors.accent).resolvedColor(with: UITraitCollection { $0.userInterfaceStyle = .dark; $0.accentTheme = .pista })
        let lilac = UIColor(BrandColors.accent).resolvedColor(with: UITraitCollection { $0.userInterfaceStyle = .dark; $0.accentTheme = .lilac })
        let ready = UIColor(BrandColors.ready).resolvedColor(with: UITraitCollection { $0.userInterfaceStyle = .dark; $0.accentTheme = .lilac })
        #expect(pista != lilac)
        #expect(ready == pista)
    }

    @Test func appearanceRenders() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        for theme in AccentTheme.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let content = VStack(alignment: .leading, spacing: 14) {
                    AccentThemePicker(selection: .constant(theme.rawValue))
                    AccentThemePreview()
                    DSNotice(tone: .success, title: "Ciclo concluído", text: "Meia de Floripa em 1:42:10.", trailing: CardLinkBadge())
                }
                .padding(16)
                .frame(width: 390)
                .background(BrandColors.background)
                .environment(\.accentTheme, theme)
                .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                let image = try #require(renderer.uiImage)
                if let output, let data = image.pngData() {
                    try data.write(to: output.appending(path: "theme-\(theme.rawValue)-\(scheme == .dark ? "dark" : "light").png"))
                }
            }
        }
    }
}

@MainActor
@Suite struct AppIconSwitcherTests {
    @Test func iconNamePerThemeAndStyle() {
        #expect(AppIconSwitcher.iconName(for: .pista, style: .system) == nil)
        #expect(AppIconSwitcher.iconName(for: .lilac, style: .system) == "AppIconLilac")
        #expect(AppIconSwitcher.iconName(for: .pista, style: .light) == "AppIconPistaLight")
        #expect(AppIconSwitcher.iconName(for: .pista, style: .dark) == "AppIconPistaDark")
        #expect(AppIconSwitcher.iconName(for: .lilac, style: .light) == "AppIconLilacLight")
        #expect(AppIconSwitcher.iconName(for: .lilac, style: .dark) == "AppIconLilacDark")
    }

    @Test func storedStyleFallsBackToSystem() {
        #expect(AppIconStyle.stored("dark") == .dark)
        #expect(AppIconStyle.stored("x") == .system)
    }

    @Test func everyIconAndPreviewIsInTheBundle() throws {
        let alternates = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])["CFBundleAlternateIcons"] as? [String: Any]
        for theme in AccentTheme.allCases {
            for style in AppIconStyle.allCases {
                if let name = AppIconSwitcher.iconName(for: theme, style: style) {
                    #expect(alternates?[name] != nil, "\(name)")
                }
            }
            let previews = AppIconSwitcher.previewNames(for: theme)
            #expect(UIImage(named: previews.light) != nil)
            #expect(UIImage(named: previews.dark) != nil)
        }
    }

    @Test func iconPickerRenders() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        for theme in AccentTheme.allCases {
            let content = AppIconStylePicker(selection: .constant(AppIconStyle.system.rawValue), theme: theme)
                .padding(16)
                .frame(width: 390)
                .background(BrandColors.background)
                .environment(\.accentTheme, theme)
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "icon-picker-\(theme.rawValue).png"))
            }
        }
    }
}
