import Foundation
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct WorkoutRowSnapshotTests {
    private static let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }

    private static func row(title: String = "Corrida fácil seg 16/11", score: Int? = 100) -> WorkoutRowData {
        WorkoutRowData(
            activityId: 1,
            title: title,
            names: [title],
            dayIso: "2026-11-16",
            dateText: "seg., 16 de nov., 06:12",
            distanceText: "12,0 km",
            durationText: "58:29",
            paceText: "4:52 /km",
            hasPrescription: true,
            score: score,
            kilometers: 12,
            zoneShares: [0.01, 0.13, 0.13, 0.73],
            weekStart: Day(iso: "2026-11-16")!
        )
    }

    private static func render(_ name: String, _ view: some View, scheme: ColorScheme, size: DynamicTypeSize = .large) throws -> CGSize {
        let content = view
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.vertical, 16)
            .frame(width: 390)
            .background(BrandColors.background)
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, size)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        #expect(image.size.width == 390)
        if let output, FileManager.default.fileExists(atPath: output.path()), let data = image.pngData() {
            try data.write(to: output.appending(path: "\(name).png"))
        }
        return image.size
    }

    @Test func rowKeepsDateAndMetricsOnOneLine() throws {
        let row = WorkoutRow(row: Self.row(), isSelected: true, isFromPlan: true)
        let light = try Self.render("workout-row-light", row, scheme: .light)
        let dark = try Self.render("workout-row-dark", row, scheme: .dark)
        let large = try Self.render("workout-row-xl", row, scheme: .light, size: .xLarge)
        #expect(light.height == dark.height)
        #expect(large.height >= light.height)
    }

    @Test func rowWithLongTitleAndNoScore() throws {
        let row = WorkoutRow(row: Self.row(title: "Limiar 4 × 2 km com aquecimento longo e desaquecimento", score: nil))
        _ = try Self.render("workout-row-long", row, scheme: .light)
    }
}
