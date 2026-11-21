import Foundation
import GarminAPI
import Insights
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct DayAdjustCardSnapshotTests {
    private static let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }

    private static func card(_ display: DayAdjustDisplay, plan: PlannedWorkout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                DSCardLabel(String(format: TodayConstants.workoutTitleFormat, TodayConstants.planTitle, TodayConstants.workoutSourceGarmin))
                Spacer()
                if let estimate = PlanText.estimate(PlanText.adjusted(plan, steps: display.steps), fallback: PaceBand(fastest: 330, slowest: 350)) {
                    Text(estimate).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            TodayGarminPlanContent(plan: plan, display: display)
            CardLinkFooter(title: CardLinkConstants.workout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    @Test func adjustedIntervalsCard() throws {
        let plan = DayAdjustTextTests.plan
        let result = DayAdjustResult.adjusted(
            steps: DayAdjustTextTests.steps(5, offset: 10), original: plan.steps, seconds: 10,
            reasons: [.heat(temperature: 27, dewPoint: 22, seconds: 7), .readiness(score: 64, seconds: 3)], shortened: false
        )
        let display = DayAdjustText.display(result, plan: plan, hour: 7)
        #expect(display.notice?.chips.count == 2)
        for (scheme, suffix) in [(ColorScheme.dark, ""), (.light, "-light")] {
            let content = Self.card(display, plan: plan)
                .padding(16)
                .frame(width: 390)
                .background(BrandColors.background)
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            #expect(image.size.width == 390)
            if let output = Self.output, FileManager.default.fileExists(atPath: output.path()), let data = image.pngData() {
                try data.write(to: output.appending(path: "day-adjust-card\(suffix).png"))
            }
        }
    }

    @Test func shortenedIntervalsShowPreviousCount() throws {
        let plan = DayAdjustTextTests.plan
        let result = DayAdjustResult.adjusted(
            steps: DayAdjustTextTests.steps(4, offset: 6), original: plan.steps, seconds: 6,
            reasons: [.readiness(score: 55, seconds: 6), .noForecast], shortened: true
        )
        let display = DayAdjustText.display(result, plan: plan, hour: 7)
        let content = Self.card(display, plan: plan).padding(16).frame(width: 390).background(BrandColors.background)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        if let output = Self.output, FileManager.default.fileExists(atPath: output.path()), let data = image.pngData() {
            try data.write(to: output.appending(path: "day-adjust-card-shortened.png"))
        }
    }
}
