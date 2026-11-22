import Foundation
import Insights
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct TrainerOutAndBackSnapshotTests {
    private static let monday = Day(year: 2026, month: 11, day: 9)
    private static let preference = TrainerDayPreference(runs: 6, optional: false, offDays: [7], longDay: 6)
    private static let target = TrainerTarget(kind: .paceDistance, name: "10 km a 4:00", distanceMeters: 10_000, goalPace: 240)

    private static var plan: TrainerPlan {
        TrainerEngine.create(
            target: target, structure: TrainerEngine.suggestedStructure(preference), strength: [], history: TrainerHistory(runs: []),
            today: monday, now: Date(timeIntervalSince1970: 1_800_000_000), startMeters: 60_000, peakMeters: 80_000, outAndBack: true
        )
    }

    private static func structure(_ workout: TrainerWorkout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(workout.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            VStack(alignment: .leading, spacing: 10) {
                TrainerShapeChart(bars: TrainerText.shapeBars(workout.steps))
                TrainerStepList(rows: TrainerText.stepRows(workout))
            }
            .brandCard()
        }
    }

    @Test func daysCardWithOutAndBack() throws {
        let structure = TrainerEngine.suggestedStructure(Self.preference)
        let cards = TrainerDaysCards(
            preference: .constant(Self.preference), structure: .constant(structure), strength: .constant([]), outAndBack: .constant(true),
            suggested: structure, meters: [:], peakMeters: 80_000, warnings: [], showsStrength: false
        )
        try TrainerDaysVolumeSnapshotTests.save(cards, name: "trainer-out-and-back-days")
    }

    @Test func thresholdAndEasyWithTurn() throws {
        let workouts = Self.plan.workouts
        let threshold = try #require(workouts.first { $0.kind == .threshold && $0.steps.contains { $0.kind == .cooldown } })
        let easy = try #require(workouts.first { $0.kind == .easy && $0.variant == nil && $0.steps.count == 2 })

        #expect(TrainerText.stepRows(threshold).contains { $0.isTurn })
        #expect(TrainerText.stepRows(easy).contains { $0.isTurn })
        try TrainerDaysVolumeSnapshotTests.save(Self.structure(threshold), name: "trainer-out-and-back-threshold")
        try TrainerDaysVolumeSnapshotTests.save(Self.structure(easy), name: "trainer-out-and-back-easy")
    }
}
