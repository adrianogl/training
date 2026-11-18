import Foundation
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct WatchChoiceSnapshotTests {
    @Test func choiceRenders() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let view = VStack(alignment: .leading, spacing: 14) {
            Text(WatchKindConstants.choiceTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
            Text(WatchKindConstants.choiceText).foregroundStyle(BrandColors.dim)
            WatchKindPicker(selection: .constant(.appleWatch))
            Button(WatchKindConstants.continueLabel) {}.buttonStyle(.ds(.primary))
            DSNotice(tone: .info, title: TodayConstants.appleBaselineTitle, text: TodayConstants.appleBaselineText)
            DSNotice(tone: .info, title: TrainerRecentRaceConstants.title, text: TrainerRecentRaceConstants.text)
        }
        .padding(20).frame(width: 390).background(BrandColors.background).environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        if let output, let data = image.pngData() { try data.write(to: output.appending(path: "watch-choice.png")) }
    }
}
