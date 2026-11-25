import Foundation
import GarminAPI
import Insights
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct DayAdjustWatchSnapshotTests {
    private let day = Day(iso: "2026-11-24")!

    private func workout() -> TrainerWorkout {
        TrainerWorkout(day: day, kind: .threshold, title: "Tempo 9 km", totalMeters: 9_000, steps: [
            TrainerStep(kind: .warmup, meters: 3_000, paceLow: 296, paceHigh: 310),
            TrainerStep(kind: .work, meters: 6_000, paceLow: 243, paceHigh: 249, method: .tempo),
        ], paceLow: 243, paceHigh: 249, rationale: "")
    }

    @Test func cardRendersWhatIsOnTheWatch() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let entries = DayAdjustEntries(
            day: day, hour: 20, origin: .usual, score: 72, temperature: 25, dewPoint: 21, radiation: nil,
            hotSessions: 6, heavyLegs: false, computedAt: Date(timeIntervalSince1970: 0)
        )
        let result = TrainerDayAdjust.adjust(workout(), entries: entries)
        guard case .adjusted(let adjustment) = result else {
            Issue.record("sem ajuste")
            return
        }
        let adjusted = adjustment.workout
        let plan = PlannedWorkout(id: 77, day: day.iso, title: adjusted.title, estimatedSeconds: nil, estimatedMeters: adjusted.totalMeters, steps: [
            PlannedStep(kind: .warmup, meters: 3_000, target: .pace(fastest: adjusted.steps[0].paceLow ?? 0, slowest: adjusted.steps[0].paceHigh ?? 0)),
            PlannedStep(kind: .active, meters: 6_000, target: .pace(fastest: adjusted.steps[1].paceLow ?? 0, slowest: adjusted.steps[1].paceHigh ?? 0)),
        ])
        let sent = Calendar.current.date(bySettingHour: 7, minute: 12, second: 0, of: .now) ?? .now
        let watch = DayAdjustWatch(entries: entries, workout: workout(), result: result, sentAt: sent)
        let display = DayAdjustText.watchDisplay(watch, plan: plan)
        let card = VStack(alignment: .leading, spacing: 10) {
            TodayGarminPlanContent(plan: plan, display: display)
            if let status = DayAdjustWatchRules.status(watch) {
                Text(status).font(.caption).foregroundStyle(BrandColors.dim).monospacedDigit()
            }
            Button {} label: { Text(String(format: DayAdjustWatchConstants.nowButtonFormat, 18)).frame(maxWidth: .infinity) }
                .buttonStyle(.ds(.secondary))
        }
        .brandCard()
        for scheme in [ColorScheme.light, .dark] {
            let view = card.padding(16).frame(width: 402).background(BrandColors.background).environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "pace-do-dia-\(scheme == .dark ? "escuro" : "claro").png"))
            }
        }
    }
}
