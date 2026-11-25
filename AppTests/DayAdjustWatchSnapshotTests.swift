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

    @Test func dayViewPanelOffersNowAndLaterHours() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let run = TrainerWorkout(day: day, kind: .easy, title: "Rodagem 10 km", totalMeters: 10_000, steps: [
            TrainerStep(kind: .steady, meters: 10_000, paceLow: 289, paceHigh: 303),
        ], paceLow: 289, paceHigh: 303, rationale: "")
        let temperatures: [Int: Double] = [12: 29, 13: 28, 14: 27, 15: 26, 16: 25, 17: 24, 18: 23, 19: 23, 20: 22, 21: 22]
        let forecast = temperatures.keys.sorted().map { HourlyWeather(hour: $0, temperature: temperatures[$0]!, dewPoint: 20) }
        let stored = DayAdjustWatchRules.retimed(
            DayAdjustEntries(day: day, hour: 20, origin: .usual, score: 72, temperature: nil, dewPoint: nil, radiation: nil, hotSessions: 2, heavyLegs: false, computedAt: .now),
            forecast: forecast, hour: 20, now: .now
        )
        let sent = Calendar.current.date(bySettingHour: 7, minute: 12, second: 0, of: .now) ?? .now
        let watch = DayAdjustWatch(entries: stored, workout: run, result: TrainerDayAdjust.adjust(run, entries: stored), sentAt: sent)
        let now = DayAdjustWatchRules.retimed(stored, forecast: forecast, hour: 12, now: .now)
        let later = DayAdjustWatchRules.laterOptions(watch, forecast: forecast, currentHour: 12, now: .now)
        #expect(later.count == 3)
        let card = VStack(alignment: .leading, spacing: 10) {
            Text("Rodagem 10 km").font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            if case let .adjusted(change) = watch.result, let line = TrainerText.dayAdjustLine(change) {
                Text(line).font(.caption).foregroundStyle(BrandColors.attention)
            }
            Divider().overlay(BrandColors.line)
            DayAdjustWatchPanel(watch: watch, nowEntries: now, later: later) { _ in nil }
        }
        .brandCard()
        for (scheme, width) in [(ColorScheme.dark, 402.0), (.light, 820.0)] {
            let view = card.padding(16).frame(width: width).background(BrandColors.background).environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "dia-relogio-\(scheme == .dark ? "escuro" : "claro").png"))
            }
        }
    }
}
