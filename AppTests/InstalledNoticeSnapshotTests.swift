import Foundation
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct InstalledNoticeSnapshotTests {
    @Test func cardRenders() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let card = InstalledCard(version: "1.26.0", notes: ["Avisa quando uma versão nova é instalada", "Notificações abrem a tela certa"], day: "2026-11-20")
        for scheme in [ColorScheme.light, .dark] {
            let screen = InstalledNotice(card: card, dismiss: {}).padding(16).frame(width: 390).background(BrandColors.background).environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: screen)
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "installed-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
    }
}
