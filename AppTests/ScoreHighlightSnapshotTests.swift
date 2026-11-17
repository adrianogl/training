import Foundation
import SwiftUI
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import trAIning

@MainActor
@Suite struct ScoreHighlightSnapshotTests {
    private static let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }

    private static func render(_ name: String, _ view: some View, scheme: ColorScheme) throws -> CGSize {
        let content = view
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.vertical, 16)
            .frame(width: 390)
            .background(BrandColors.background)
            .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        if let output, FileManager.default.fileExists(atPath: output.path()), let data = image.pngData() {
            try data.write(to: output.appending(path: "\(name).png"))
        }
        return image.size
    }

    private static let perfectRow = WorkoutRowData(
        activityId: 1, title: "Corrida fácil seg 16/11", names: ["Corrida fácil seg 16/11"], dayIso: "2026-11-16",
        dateText: "seg., 16 de nov., 06:12", distanceText: "12,0 km", durationText: "58:29", paceText: "4:52 /km",
        hasPrescription: true, score: 100, kilometers: 12, zoneShares: [0.01, 0.13, 0.13, 0.73], weekStart: Day(iso: "2026-11-16")!
    )

    private static let fullRows = [
        ScoreRowData(part: .execution, name: "Execução", points: 50, maximum: 50, pointsText: "50/50", reasonText: nil),
        ScoreRowData(part: .intent, name: "Intenção", points: 25, maximum: 25, pointsText: "25/25", reasonText: nil),
        ScoreRowData(part: .cost, name: "Custo", points: 25, maximum: 25, pointsText: "25/25", reasonText: "mais eficiente que nos treinos anteriores"),
    ]

    private static let signals = [
        AboveExpectedSignal(kind: .heartRateAtPace, before: 168, today: 163, compared: 3),
        AboveExpectedSignal(kind: .recoveryDrop, before: 29, today: 38, compared: 3),
    ]

    @Test func perfectRowShowsThePill() throws {
        for scheme in [ColorScheme.light, .dark] {
            let size = try Self.render("perfect-row-\(scheme)", WorkoutRow(row: Self.perfectRow, isFromPlan: true), scheme: scheme)
            #expect(size.width == 390)
        }
    }

    @Test func perfectSummaryShowsTitleAndLine() throws {
        let card = ScoreSummaryCard(value: 100, rows: Self.fullRows, perfectLine: "4 de 4 blocos no alvo e mais eficiente que nos treinos iguais")
        for scheme in [ColorScheme.light, .dark] {
            _ = try Self.render("perfect-summary-\(scheme)", card, scheme: scheme)
        }
    }

    @Test func aboveExpectedGroupShowsBars() throws {
        for scheme in [ColorScheme.light, .dark] {
            _ = try Self.render("above-expected-\(scheme)", AboveExpectedGroup(signals: Self.signals), scheme: scheme)
        }
    }

    @Test func todayCardsShowThePerfectBadge() throws {
        let run = LastRunSummary(
            activityId: 2, title: "Corrida fácil", dateText: "seg., 16/11", kilometers: 12, paceSeconds: 292, averageHeartRate: 147,
            evolution: nil, evolutionOnDevice: false, notice: nil, score: 100, kind: .easy, fadeKm: nil
        )
        for scheme in [ColorScheme.light, .dark] {
            _ = try Self.render("today-compact-\(scheme)", LastRunCompactCard(lastRun: run, plannedKm: 12), scheme: scheme)
        }
    }

    @Test func perfectLineCountsTargetedBlocks() {
        let score = WorkoutScore(value: 100, items: [])
        #expect(ScoreRows.perfectLine(score, blocks: []) == ScoreConstants.perfectLineAllTargets)
        #expect(ScoreRows.perfectLine(WorkoutScore(value: 99, items: []), blocks: []) == nil)
    }
}
