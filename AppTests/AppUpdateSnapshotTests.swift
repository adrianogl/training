import Foundation
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct AppUpdateSnapshotTests {
    @Test func noticeRenders() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let update = AppUpdate(latest: "1.11.0", installed: "1.9.0", notes: ["Escolha do ícone entre claro e escuro", "Correção do total da semana no relatório"])
        let screen = VStack(alignment: .leading, spacing: 10) {
            AppUpdateNotice(update: update, openSettings: {}, dismiss: {})
            Text(AppUpdateText.footer(update)).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.attention).frame(maxWidth: .infinity)
        }
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: screen.padding(16).frame(width: 390).background(BrandColors.background).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "app-update-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
    }
}
