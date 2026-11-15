import Foundation
import Insights
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct TrainerCycleSnapshotTests {
    private static let day = Day(iso: "2026-08-03")!
    private static let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }

    private static func review(_ verdict: TrainerCycleVerdict, readiness: Bool = true) -> TrainerCycleReview {
        let planned: [Double] = [52, 56, 60, 48, 64, 68, 72, 58, 76, 80, 84, 62, 70, 50, 34]
        let done: [Double] = [50, 55, 61, 47, 62, 66, 52, 57, 75, 81, 82, 60, 68, 49, 33]
        let weeks = planned.indices.map {
            TrainerCycleWeek(index: $0 + 1, start: day.adding(days: $0 * 7), doneMeters: done[$0] * 1_000, plannedMeters: planned[$0] * 1_000)
        }
        let increase = verdict == .increase
        return TrainerCycleReview(
            first: day, last: day.adding(days: planned.count * 7 - 1), endedEarly: false, weeks: weeks,
            long: TrainerCycleCount(done: increase ? 14 : 9, total: 15),
            threshold: TrainerCycleCount(done: increase ? 13 : 11, total: 14),
            vo2: TrainerCycleCount(done: increase ? 12 : 7, total: 13),
            mediumLong: TrainerCycleCount(done: 10, total: 12),
            longestLongMeters: 24_000, longestLongPlannedMeters: 26_000,
            readinessFirst: readiness ? 72 : nil, readinessLast: readiness ? (increase ? 75 : 63) : nil,
            lowReadinessDays: increase ? 3 : 11, extraLightWeeks: increase ? [] : [day.adding(days: 42), day.adding(days: 70)],
            longsMissed: increase ? 1 : 6,
            predictions: [
                TrainerCycleChange(meters: 10_000, first: 2_460, last: increase ? 2_412 : 2_478),
                TrainerCycleChange(meters: 21_097.5, first: 5_520, last: increase ? 5_412 : 5_560),
            ],
            raceSeconds: increase ? 5_628 : nil, goalSeconds: 5_700,
            verdict: verdict,
            reasons: increase
                ? [.volume(share: 0.97, weeksBelow: 1), .readiness(first: 72, last: 75), .race(seconds: 5_628, goal: 5_700)]
                : [.volume(share: 0.72, weeksBelow: 5), .readiness(first: 72, last: 63), .lightWeeks(2)],
            currentStartMeters: 52_000, currentPeakMeters: 84_000,
            suggestedStartMeters: increase ? 56_000 : 47_000, suggestedPeakMeters: increase ? 90_000 : 76_000
        )
    }

    private static func cells() -> [TrainerWeekCell] {
        (0..<5).map {
            TrainerWeekCell(
                id: $0 + 11, title: "S\($0 + 11)", kilometers: "\(62 - $0 * 6)", detail: "18 km",
                phase: .taper, isCurrent: false, isPast: true, isChanged: false, isRace: false
            )
        }
    }

    @discardableResult
    private static func render(_ name: String, _ view: some View) throws -> CGSize {
        let content = view
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.vertical, 16)
            .frame(width: 390)
            .background(BrandColors.background)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        #expect(image.size.width == 390)
        if let output, FileManager.default.fileExists(atPath: output.path()), let data = image.pngData() {
            try data.write(to: output.appending(path: "\(name).png"))
        }
        return image.size
    }

    @Test func analysisWithIncrease() throws {
        let size = try Self.render("analysis-increase", TrainerCycleContent(
            plan: TrainerStoreTests.plan(), review: Self.review(.increase), ended: true, onSuggestion: {}, onOther: {}
        ))
        #expect(size.height > size.width * 3)
    }

    @Test func analysisWithDecrease() throws {
        let size = try Self.render("analysis-decrease", TrainerCycleContent(
            plan: TrainerStoreTests.plan(), review: Self.review(.decrease, readiness: false), ended: false, onSuggestion: {}, onOther: {}
        ))
        #expect(size.height > size.width * 3)
    }

    @Test func analysisWithoutWeeksIsShorter() throws {
        var empty = Self.review(.keep)
        empty.weeks = []
        let full = try Self.render("analysis-full", TrainerCycleContent(
            plan: TrainerStoreTests.plan(), review: Self.review(.keep), ended: true, onSuggestion: {}, onOther: {}
        ))
        let short = try Self.render("analysis-no-weeks", TrainerCycleContent(
            plan: TrainerStoreTests.plan(), review: empty, ended: true, onSuggestion: {}, onOther: {}
        ))
        #expect(short.height < full.height)
    }

    @Test func headerWhenEnded() throws {
        let plan = TrainerStoreTests.plan()
        let review = Self.review(.increase)
        let summary = TrainerCycleSummary(
            title: "Meia de Floripa", first: Self.day, last: Self.day, verdict: .increase,
            beforePeakMeters: 76_000, afterPeakMeters: 84_000, resultSeconds: 5_712
        )
        let size = try Self.render("trainer-ended", VStack(alignment: .leading, spacing: 10) {
            TrainerCycleBanner(review: review, dated: true)
            TrainerPlanHeaderCard(
                plan: plan, boards: [], cells: Self.cells(), weeksToTarget: nil, weekProgress: nil,
                onToggleLight: { _ in }, onSelect: { _ in }, cycle: review
            )
            Button(TrainerCycleText.openAnalysis) {}.buttonStyle(TrainerPrimaryButtonStyle())
            Button(TrainerText.newPlanTitle) {}.buttonStyle(TrainerSecondaryButtonStyle())
            SectionHeader(TrainerCycleText.previousTitle)
            TrainerCycleSummaryRow(summary: summary)
        })
        #expect(size.height > size.width)
    }
}
