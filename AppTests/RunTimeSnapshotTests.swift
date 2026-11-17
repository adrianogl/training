import Foundation
import GarminAPI
import Insights
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct RunTimeSnapshotTests {
    private static let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
    private static let day = Day(iso: "2026-11-17")!
    private static let threshold = TrainerWorkout(
        day: day, kind: .threshold, title: "Limiar", totalMeters: 9_500,
        steps: [
            TrainerStep(kind: .warmup, meters: 2_000, paceLow: 360, paceHigh: 390),
            TrainerStep(kind: .work, repeats: 4, meters: 1_500, paceLow: 290, paceHigh: 300),
            TrainerStep(kind: .recovery, repeats: 3, meters: 0, restSeconds: 90),
        ],
        paceLow: 290, paceHigh: 300, rationale: ""
    )
    private static let intervals = PlannedWorkout(
        id: 1, day: "2026-11-18", title: "Intervalado 8 × 400 m", estimatedSeconds: 2_700, estimatedMeters: 6_400,
        steps: [
            PlannedStep(kind: .warmup, seconds: 900),
            PlannedStep(kind: .other, repeats: 8, children: [
                PlannedStep(kind: .active, meters: 400, target: .pace(fastest: 250, slowest: 260)),
                PlannedStep(kind: .recovery, seconds: 60),
            ]),
            PlannedStep(kind: .cooldown, seconds: 600),
        ]
    )

    @Test func rowsShowTheEstimate() throws {
        let estimate = TrainerEngine.timeEstimate(Self.threshold, fallback: nil)
        let row = TrainerDayRow(workout: Self.threshold, status: .planned, run: nil, isChanged: false, estimate: estimate)
        #expect(TrainerText.dayLine(Self.threshold, estimate: estimate).title == "Limiar · 9,5 km · 54–58 min")
        #expect(PlanText.estimate(Self.intervals, fallback: nil) == "6,4 km · 46–47 min")
        for scheme in [ColorScheme.light, .dark] {
            try Self.render("tempo-\(scheme == .dark ? "escuro" : "claro")", VStack(spacing: 12) {
                TrainerDayRowView(row: row, isToday: true)
                PlannedWorkoutRow(plan: Self.intervals, isToday: false)
            }, scheme: scheme)
        }
    }

    private static func render(_ name: String, _ view: some View, scheme: ColorScheme) throws {
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
    }
}
