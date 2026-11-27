import Foundation
import GarminAPI
import Insights
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct TrainerZoneEvolutionSnapshotTests {
    private static let start = Day(year: 2026, month: 9, day: 7)

    private static var trend: TrainerZoneTrend {
        let thresholds: [Double] = [261, 261, 259, 259, 258, 257, 257, 256, 255, 255, 254, 253]
        let weeks = thresholds.enumerated().map { index, t in
            let marathon = t * 1.08
            let easy = max(296, marathon * 1.1)
            let vo2 = t - 22
            let offset = Double(index)
            return TrainerZoneWeek(
                start: start.adding(days: index * 7), threshold: t,
                targets: [
                    TrainerZoneTarget(zone: 1, paceLow: easy + 7, paceHigh: nil, heartRateLow: nil, heartRateHigh: 139),
                    TrainerZoneTarget(zone: 2, paceLow: easy - 7, paceHigh: easy + 7, heartRateLow: 140, heartRateHigh: 148),
                    TrainerZoneTarget(zone: 3, paceLow: marathon - 3, paceHigh: marathon + 3, heartRateLow: 149, heartRateHigh: 156),
                    TrainerZoneTarget(zone: 4, paceLow: t - 8, paceHigh: t + 3, heartRateLow: 157, heartRateHigh: 167),
                    TrainerZoneTarget(zone: 5, paceLow: vo2 - 3, paceHigh: vo2 + 3, heartRateLow: 168, heartRateHigh: nil),
                ],
                actual: [
                    1: TrainerZoneActual(pace: nil, heartRate: 136 - offset / 3),
                    2: TrainerZoneActual(pace: 303 - offset * 0.6, heartRate: 154 - offset / 2),
                    3: index == 4 ? TrainerZoneActual() : TrainerZoneActual(pace: 280 - offset * 0.8, heartRate: 160 - offset / 2),
                    4: index == 6 ? TrainerZoneActual() : TrainerZoneActual(pace: 252 - offset * 0.6, heartRate: 164 - offset / 2.5),
                    5: TrainerZoneActual(pace: 242 - offset * 0.1, heartRate: 170 - offset / 5),
                ].filter { $0.value.pace != nil || $0.value.heartRate != nil }
            )
        }
        return TrainerZoneTrend(
            weeks: weeks, goalThreshold: 235,
            averages: [
                1: TrainerZoneActual(pace: nil, heartRate: 134), 2: TrainerZoneActual(pace: 299.5, heartRate: 151),
                3: TrainerZoneActual(pace: 275.6, heartRate: 157), 4: TrainerZoneActual(pace: 248.6, heartRate: 161.6),
                5: TrainerZoneActual(pace: 241, heartRate: 168.4),
            ]
        )
    }

    @Test func zoneCardFollowsTheMock() throws {
        try TrainerDaysVolumeSnapshotTests.save(TrainerZoneGuideCard(trend: Self.trend, hasHeartRate: true), name: "zonas-ritmo-z4")
        try TrainerDaysVolumeSnapshotTests.save(
            TrainerZoneGuideCard(trend: Self.trend, hasHeartRate: true, zones: Set(1...5)), name: "zonas-ritmo-todas"
        )
        try TrainerDaysVolumeSnapshotTests.save(
            TrainerZoneGuideCard(trend: Self.trend, hasHeartRate: true, mode: .heartRate, zones: [2, 4]), name: "zonas-fc"
        )
    }

    @Test func vo2WithStrides() throws {
        let plan = TrainerEngine.create(
            target: TrainerTarget(kind: .paceDistance, name: "10 km a 4:00", distanceMeters: 10_000, goalPace: 240),
            structure: TrainerEngine.suggestedStructure(TrainerDayPreference(runs: 6, optional: false, offDays: [7], longDay: 6)), strength: [],
            history: TrainerHistory(runs: []), today: Day(year: 2026, month: 11, day: 9), now: Date(timeIntervalSince1970: 1_800_000_000),
            startMeters: 60_000, peakMeters: 80_000
        )
        let workout = try #require(plan.workouts.first { $0.kind == .vo2max && $0.steps.contains(where: \.isStrides) })
        let trainer = VStack(alignment: .leading, spacing: 10) {
            Text(workout.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            VStack(alignment: .leading, spacing: 10) {
                TrainerShapeChart(bars: TrainerText.shapeBars(workout.steps))
                TrainerStepList(rows: TrainerText.stepRows(workout))
                Text(TodayConstants.stridesNote).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
            }
            .brandCard()
        }
        #expect(workout.steps.contains { $0.isStrides })
        try TrainerDaysVolumeSnapshotTests.save(trainer, name: "vo2-strides-treinador")

        let steps = TrainerSendBuilder.runSteps(workout, thresholdHeartRate: 172, maxHeartRate: 190).map(Self.planned)
        let today = VStack(alignment: .leading, spacing: 10) {
            Text(workout.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            PlannedStepsList(steps: steps)
            Text(TodayConstants.stridesNote).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
        }
        .brandCard()
        #expect(steps.contains { $0.isStrides })
        try TrainerDaysVolumeSnapshotTests.save(today, name: "vo2-strides-hoje")
    }

    @Test func swapToTheEveOfTheLong() throws {
        let monday = Day(year: 2026, month: 11, day: 30)
        func workout(_ offset: Int, _ kind: TrainerDayKind, meters: Double = 8_000) -> TrainerWorkout {
            TrainerWorkout(day: monday.adding(days: offset), kind: kind, title: "", totalMeters: meters, steps: [], rationale: "")
        }
        let plan = TrainerPlan(
            target: TrainerTarget(kind: .text, name: "Aberto"), structure: [:], paces: TrainerPaces(easy: 300, long: 300, threshold: 250, vo2max: 230),
            weeks: [], workouts: [
                workout(0, .easy), workout(1, .threshold), workout(2, .easy), workout(3, .vo2max), workout(4, .optionalEasy),
                workout(5, .long, meters: 20_000), workout(6, .off, meters: 0),
            ], versions: []
        )
        let days = [0, 2, 4, 5].map { monday.adding(days: $0) }
        let warning = try #require(TrainerEngine.swapWarning(plan: plan, day: monday.adding(days: 3), other: monday.adding(days: 4), candidates: days))
        let card = VStack(alignment: .leading, spacing: 8) {
            DSCardLabel(TrainerText.swapTitle)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: TrainerConstants.swapColumns), spacing: 6) {
                ForEach(days, id: \.iso) { day in
                    let chosen = day == monday.adding(days: 4)
                    Text(TrainerText.swapChip(day))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(chosen ? BrandColors.accent : BrandColors.dim)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(chosen ? BrandColors.accentGlow : BrandColors.track, in: RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
                }
            }
            DSNotice(tone: .attention, title: warning.title, text: warning.text)
            Text(TrainerText.swapHint).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
        try TrainerDaysVolumeSnapshotTests.save(card, name: "troca-vespera-longao")
    }

    private static func planned(_ step: PlannedRunStep) -> PlannedStep {
        switch step {
        case let .warmup(meters, fastest, slowest, _): PlannedStep(kind: .warmup, meters: meters, target: pace(fastest, slowest))
        case let .cooldown(meters, fastest, slowest, _): PlannedStep(kind: .cooldown, meters: meters, target: pace(fastest, slowest))
        case let .interval(meters, fastest, slowest, _): PlannedStep(kind: .active, meters: meters, target: pace(fastest, slowest))
        case let .recovery(meters): PlannedStep(kind: .recovery, meters: meters)
        case let .rest(seconds): PlannedStep(kind: .rest, seconds: seconds)
        case let .repeated(times, steps): PlannedStep(kind: .other, repeats: times, children: steps.map(planned))
        }
    }

    private static func pace(_ fastest: Double?, _ slowest: Double?) -> PlannedTarget? {
        guard let fastest, let slowest else { return nil }
        return .pace(fastest: fastest, slowest: slowest)
    }
}
