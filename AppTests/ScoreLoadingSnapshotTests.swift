import Foundation
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct ScoreLoadingSnapshotTests {
    private static let row = WorkoutRowData(
        activityId: 1, title: "Tempo 9 km", names: ["Tempo 9 km"], dayIso: "2026-11-24", dateText: "ter., 24 de nov., 20:00",
        distanceText: "9,0 km", durationText: "40:57", paceText: "4:33/km", hasPrescription: true, score: nil,
        kilometers: 9, zoneShares: [0.05, 0.3, 0.15, 0.35, 0.15], weekStart: Day(iso: "2026-11-23")!, scorePending: true
    )

    @Test func loadingStatesRender() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let screen = VStack(alignment: .leading, spacing: 16) {
            DSSectionTitle(WorkoutDetailConstants.sectionScore)
            ScoreLoadingCard(pending: .weather, showsLabel: false)
            WorkoutRow(row: Self.row)
            HStack { Spacer(); ScoreLoadingBadge() }.brandCard()
        }
        for scheme in [ColorScheme.light, .dark] {
            let view = screen.padding(16).frame(width: 402).background(BrandColors.background).environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "nota-carregando-\(scheme == .dark ? "escuro" : "claro").png"))
            }
        }
    }
}
