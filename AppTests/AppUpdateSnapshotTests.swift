import Foundation
import SwiftUI
import Testing
import UIKit
@testable import trAIning

@MainActor
@Suite struct AppUpdateSnapshotTests {
    @Test func noticeRenders() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let update = AppUpdate(latest: "1.11.0", installed: "1.9.0", notes: ["Escolha do ícone entre claro e escuro", "Correção do total da semana no relatório"])
        let screen = VStack(alignment: .leading, spacing: 10) {
            AppUpdateNotice(update: update, openSettings: {}, dismiss: {})
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

    @Test func versionSectionRenders() async throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        let current = AppVersionSummary(installed: "1.31.0", latest: "1.31.0", hasUpdate: false, notesVersion: "1.31.0", notes: ["Recorde pessoal em destaque", "Meta cumprida na lista e no aviso"])
        let behind = AppVersionSummary(installed: "1.30.0", latest: "1.31.0", hasUpdate: true, notesVersion: "1.31.0", notes: ["Recorde pessoal em destaque"])
        let form = List {
            SettingsVersionSection(summary: current, build: "43")
            SettingsVersionSection(summary: behind, build: "42")
        }
        .scrollContentBackground(.hidden)
        .background(BrandColors.background)
        .environment(\.colorScheme, .dark)
        let host = UIHostingController(rootView: form)
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 440, height: 700)
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(800))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try image.pngData()?.write(to: URL(filePath: dir).appending(path: "settings-version.png"))
        window.isHidden = true
    }
}
