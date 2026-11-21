import Foundation
import Insights
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct StrengthPlanSnapshotTests {
    private static let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
    private static let start = Day(iso: "2026-11-24")!

    private static func plan() -> StrengthPlan {
        StrengthPlan(
            objective: .mobility, sessions: [2, 4].map { StrengthPlanDraftLogic.newSession(objective: .mobility, weekday: $0) },
            start: start, validity: .weeks(8), builder: .trainer
        )
    }

    @discardableResult
    private static func render(_ name: String, _ view: some View) throws -> CGSize {
        let content = VStack(alignment: .leading, spacing: StrengthPlanUIConstants.spacing) { view }
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
            try data.write(to: output.appending(path: "strength-plan-\(name).png"))
        }
        return image.size
    }

    private static var mfit: StrengthMFITSummary {
        StrengthPlanDraftLogic.mfitSummary(StrengthPlanUITests.mfitSessions(), ended: false)!
    }

    @Test func form() throws {
        var draft = StrengthPlanDraftLogic.empty(objective: .mobility, today: Day(iso: "2026-11-20")!, race: nil)
        draft.sessions = Self.plan().sessions
        draft.start = Self.start
        let size = try Self.render("1-form", StrengthPlanFormContent(
            draft: .constant(draft), confirmingEnd: .constant(false), today: Day(iso: "2026-11-20")!,
            onEditSession: { _ in }, onAddDay: {}, onSubmit: {}, onEnd: {}
        ))
        #expect(size.height > 700)
    }

    @Test func activeCard() throws {
        try Self.render("2-active", Group {
            StrengthPlanCard(summary: StrengthPlanDraftLogic.cardSummary(Self.plan(), done: 6, today: Day(iso: "2026-12-08")!)) {}
            StrengthMFITCard(summary: Self.mfit)
        })
    }

    @Test func futureCard() throws {
        try Self.render("2b-future", StrengthPlanCard(summary: StrengthPlanDraftLogic.cardSummary(Self.plan(), done: 0, today: Day(iso: "2026-11-20")!)) {})
    }

    @Test func dayWithBoth() throws {
        try Self.render("3-day", Group {
            StrengthDayCard(model: StrengthPlanDraftLogic.mfitDayCard(title: "Treino B · inferiores", exercises: 6, sets: 18))
            StrengthDayCard(model: StrengthPlanDraftLogic.planDayCard(
                group: .mobility, minutes: 20, exercises: 7, week: 3, weeks: 8, note: nil, isClaude: false, isDone: false
            ))
        })
    }

    @Test func endedNotice() throws {
        try Self.render("4-ended", Group {
            StrengthPlanEndedNotice(summary: StrengthPlanDraftLogic.endedSummary(Self.plan(), done: 15))
            StrengthMFITCard(summary: StrengthPlanDraftLogic.mfitSummary(StrengthPlanUITests.mfitSessions(), ended: true)!)
            Button(StrengthPlanText.nextPlan) {}.buttonStyle(.ds(.primary))
            Button(StrengthPlanText.repeatPlan) {}.buttonStyle(.ds(.secondary))
        })
    }

    @Test func migrationNotice() throws {
        try Self.render("5-migration", StrengthPlanMigrationNotice(text: StrengthPlanText.migration(end: Self.plan().end), onAdjust: {}, onDismiss: {}))
    }
}
