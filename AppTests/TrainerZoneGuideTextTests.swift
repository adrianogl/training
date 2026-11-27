import Foundation
import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerZoneGuideTextTests {
    private let start = Day(iso: "2026-09-07")!

    private func week(_ index: Int, threshold: Double, z4: Double?) -> TrainerZoneWeek {
        TrainerZoneWeek(
            start: start.adding(days: index * 7), threshold: threshold,
            targets: [
                TrainerZoneTarget(zone: 1, paceLow: 303, paceHigh: nil, heartRateLow: nil, heartRateHigh: 139),
                TrainerZoneTarget(zone: 4, paceLow: 245, paceHigh: 256, heartRateLow: 157, heartRateHigh: 167),
                TrainerZoneTarget(zone: 5, paceLow: 229, paceHigh: 235, heartRateLow: 168, heartRateHigh: nil),
            ],
            actual: z4.map { [4: TrainerZoneActual(pace: $0, heartRate: 160)] } ?? [:]
        )
    }

    private var trend: TrainerZoneTrend {
        let weeks = (0..<12).map { week($0, threshold: 261 - Double($0), z4: $0 == 5 ? nil : 252 - Double($0) / 2) }
        return TrainerZoneTrend(
            weeks: weeks, goalThreshold: 235,
            averages: [4: TrainerZoneActual(pace: 262, heartRate: 170), 1: TrainerZoneActual(pace: nil, heartRate: 132)]
        )
    }

    @Test func summaryShowsTheChangeAndTheGapToTheGoal() {
        #expect(TrainerZoneGuideText.change(trend, at: 11) == "−6 s em 6 sem.")
        #expect(TrainerZoneGuideText.change(trend, at: 3) == "início")
        #expect(TrainerZoneGuideText.gap(trend, at: 11) == "faltam 15 s para a meta")
        var open = trend
        open.goalThreshold = nil
        #expect(TrainerZoneGuideText.gap(open, at: 11) == nil)
    }

    @Test func rowsSayHowFarOutsideTheTarget() throws {
        let rows = TrainerZoneGuideText.rows(trend, week: trend.weeks[11])
        let z4 = try #require(rows.first { $0.zone == 4 })
        let z1 = try #require(rows.first { $0.zone == 1 })
        let z5 = try #require(rows.first { $0.zone == 5 })

        #expect(TrainerZoneGuideText.zoneName(4) == "Z4 limiar")
        #expect(z4.paceTarget == "4:05–4:16" && z4.pace == "4:22" && z4.paceNote == "6 s lento")
        #expect(z4.heartRateTarget == "157–167" && z4.heartRate == "170" && z4.heartRateNote == "3 acima")
        #expect(z1.paceTarget == "> 5:03" && z1.pace == "—" && z1.heartRateTarget == "< 140" && z1.heartRateNote == nil)
        #expect(z5.heartRateTarget == "≥ 168" && !z5.hasPace)
    }

    @Test func weekWithoutTheZoneBreaksTheLine() {
        let points = TrainerZoneGuideText.points(trend, zones: [4], mode: .pace)

        #expect(points.count == 11)
        #expect(Set(points.filter { $0.index < 5 }.map(\.series)) == ["4-0"])
        #expect(Set(points.filter { $0.index > 5 }.map(\.series)) == ["4-1"])
        #expect(points.first?.value == -252)
    }

    @Test func paceChartPutsTheFasterPaceOnTop() {
        let bands = TrainerZoneGuideText.bands(trend, zones: [4], mode: .pace)
        let points = TrainerZoneGuideText.points(trend, zones: [4], mode: .pace)
        let domain = TrainerZoneGuideText.domain(bands: bands, points: points, goal: -235, mode: .pace)

        #expect(bands.first?.low == -256 && bands.first?.high == -245)
        #expect(domain.upperBound >= -232 && domain.lowerBound <= -259)
        #expect(TrainerZoneGuideText.axisLabel(-245, mode: .pace) == "4:05")
    }
}
