import SwiftUI
import Testing
import UIKit
@testable import trAIning

@MainActor
@Suite struct DSCardRowSnapshotTests {
    @Test func cardRowsKeepBordersInsideFormSections() async throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        do {
            let form = Form {
                Section("Cor de destaque") { AccentThemePicker(selection: .constant(AccentTheme.pista.rawValue)).dsCardRow() }
                Section("Relógio") { WatchKindPicker(selection: .constant(.garmin)).dsCardRow() }
            }
            .scrollContentBackground(.hidden)
            .background(BrandColors.background)
            .environment(\.colorScheme, .dark)
            let host = UIHostingController(rootView: form)
            let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 900, height: 700)
            window.rootViewController = host
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(800))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try image.pngData()?.write(to: URL(filePath: dir).appending(path: "card-row-form.png"))
            window.isHidden = true
        }
    }
}
