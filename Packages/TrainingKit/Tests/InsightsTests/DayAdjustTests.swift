import Foundation
import GarminAPI
import Testing
import TrainingCore
@testable import Insights

@Suite struct DayAdjustTests {
    private func pace(_ step: PlannedStep) -> (Double, Double)? {
        guard case let .pace(fastest, slowest)? = step.target else { return nil }
        return (fastest, slowest)
    }

    private func continuous(meters: Double = 10_000) -> PlannedWorkout {
        PlannedWorkout(id: 1, day: "2026-11-21", title: "Contínuo", estimatedSeconds: nil, estimatedMeters: nil, steps: [
            PlannedStep(kind: .warmup, meters: 3_000, target: .pace(fastest: 300, slowest: 320)),
            PlannedStep(kind: .active, meters: meters, target: .pace(fastest: 240, slowest: 248)),
        ])
    }

    private func intervals() -> PlannedWorkout {
        let group = PlannedStep(kind: .other, repeats: 5, children: [
            PlannedStep(kind: .active, meters: 1_000, target: .pace(fastest: 240, slowest: 248)),
            PlannedStep(kind: .recovery, seconds: 150),
        ])
        return PlannedWorkout(id: 2, day: "2026-11-21", title: "Tiros", estimatedSeconds: nil, estimatedMeters: nil, steps: [
            PlannedStep(kind: .warmup, meters: 3_000, target: .pace(fastest: 300, slowest: 320)),
            group,
        ])
    }

    private func input(
        _ plan: PlannedWorkout, shape: DayAdjustShape = .continuous, score: Int? = 80, temperature: Double? = 12,
        dewPoint: Double? = 5, hotSessions: Int = 0, heavyLegs: Bool = false
    ) -> DayAdjustInput {
        DayAdjustInput(
            plan: plan, shape: shape, score: score, temperature: temperature, dewPoint: dewPoint,
            hotSessions: hotSessions, heavyLegs: heavyLegs
        )
    }

    private func adjusted(_ result: DayAdjustResult) -> (steps: [PlannedStep], seconds: Int, reasons: [DayAdjustReason], shortened: Bool)? {
        guard case let .adjusted(steps, _, seconds, reasons, shortened) = result else { return nil }
        return (steps, seconds, reasons, shortened)
    }

    @Test func strongReadinessWithoutHeatChangesNothing() {
        #expect(DayAdjust.adjust(input(continuous(), score: 75, temperature: 12, dewPoint: 5)) == .none)
    }

    @Test func moderateStepAddsThreeSecondsToActiveOnly() throws {
        let result = try #require(adjusted(DayAdjust.adjust(input(continuous(), score: 64))))
        #expect(result.seconds == 3)
        #expect(pace(result.steps[1]).map { [$0.0, $0.1] } == [243, 251])
        #expect(pace(result.steps[0]).map { [$0.0, $0.1] } == [300, 320])
        #expect(result.shortened == false)
    }

    @Test func heatUsesAnalysisTable() throws {
        let expected = Int((WeatherAdjustment.heatFactor(temperature: 27, dewPoint: 22) * 244).rounded())
        let result = try #require(adjusted(DayAdjust.adjust(input(continuous(), score: 80, temperature: 27, dewPoint: 22))))
        #expect(expected > 0)
        #expect(result.seconds == expected)
        #expect(result.reasons == [.heat(temperature: 27, dewPoint: 22, seconds: expected)])
        #expect(pace(result.steps[1])?.0 == 240 + Double(expected))
    }

    @Test func mildHeatBelowThreeSecondsIsIgnored() {
        let raw = Int((WeatherAdjustment.heatFactor(temperature: 18, dewPoint: 10) * 244).rounded())
        #expect(raw > 0 && raw < RunWeatherConstants.minimumHeatSeconds)
        #expect(DayAdjust.adjust(input(continuous(), score: 80, temperature: 18, dewPoint: 10)) == .none)
        let readiness = adjusted(DayAdjust.adjust(input(continuous(), score: 64, temperature: 18, dewPoint: 10)))
        #expect(readiness?.reasons == [.readiness(score: 64, seconds: 3)])
        #expect(readiness?.seconds == 3)
    }

    @Test func acclimatizationReducesHeat() throws {
        let factor = WeatherAdjustment.heatFactor(temperature: 27, dewPoint: 22) * (1 - WeatherAdjustment.adaptation(hotSessions: 4))
        let expected = Int((factor * 244).rounded())
        let result = try #require(adjusted(DayAdjust.adjust(input(continuous(), score: 80, temperature: 27, dewPoint: 22, hotSessions: 4))))
        let full = Int((WeatherAdjustment.heatFactor(temperature: 27, dewPoint: 22) * 244).rounded())
        #expect(result.seconds == expected)
        #expect(expected < full)
    }

    @Test func lowStepDropsATiroAndKeepsTheStrides() throws {
        var plan = intervals()
        plan.steps.insert(PlannedStep(kind: .other, repeats: 4, children: [
            PlannedStep(kind: .active, meters: 100, target: .pace(fastest: 210, slowest: 216)),
            PlannedStep(kind: .recovery, meters: 100),
        ]), at: 1)
        let result = try #require(adjusted(DayAdjust.adjust(input(plan, shape: .intervals, score: 55))))

        #expect(result.steps[1].repeats == 4 && result.steps[1].isStrides)
        #expect(result.steps[2].repeats == 4)
    }

    @Test func lowStepDropsOneRepeatInIntervals() throws {
        let result = try #require(adjusted(DayAdjust.adjust(input(intervals(), shape: .intervals, score: 55))))
        #expect(result.steps[1].repeats == 4)
        #expect(result.seconds == 6)
        #expect(result.shortened == true)
        #expect(pace(result.steps[1].children[0]).map { [$0.0, $0.1] } == [246, 254])
    }

    @Test func lowStepShortensContinuousBy20Percent() throws {
        let result = try #require(adjusted(DayAdjust.adjust(input(continuous(), score: 55))))
        #expect(result.steps[1].meters == 8_000)
        #expect(result.steps[0].meters == 3_000)
        #expect(result.shortened == true)
    }

    @Test func outAndBackLongRunShortensBothHalves() throws {
        let half = PlannedStep(kind: .active, meters: 8_000, target: .pace(fastest: 300, slowest: 320))
        let plan = PlannedWorkout(id: 3, day: "2026-11-21", title: "Longão 16 km", estimatedSeconds: nil, estimatedMeters: nil, steps: [half, half])

        #expect(PlannedStep.activeBlocks(plan.steps) == 1)
        #expect(PlannedStep.isSplitContinuous(plan.steps))
        #expect(PlannedStep.activeBlocks(intervals().steps) == 5)
        let result = try #require(adjusted(DayAdjust.adjust(input(plan, shape: .long, score: 55))))
        #expect(result.steps.map(\.meters) == [6_400, 6_400])
    }

    @Test func heavyLegsAddsThreeSecondsOnLongRun() throws {
        let result = try #require(adjusted(DayAdjust.adjust(input(continuous(), shape: .long, score: 80, heavyLegs: true))))
        #expect(result.seconds == 3)
        #expect(result.reasons == [.heavyLegs(seconds: 3)])
        #expect(pace(result.steps[1])?.0 == 243)
    }

    @Test func reasonsSumAndCapAt15() {
        let result = DayAdjust.adjust(input(continuous(), shape: .long, score: 55, temperature: 27, dewPoint: 22, heavyLegs: true))
        guard case let .swap(reasons) = result else {
            Issue.record("esperava swap, veio \(result)")
            return
        }
        #expect(reasons.count == 3)
    }

    @Test func belowFiftyIsRest() {
        #expect(DayAdjust.adjust(input(continuous(), score: 45)) == .rest)
    }

    @Test func missingForecastAddsNoForecastReason() throws {
        let result = try #require(adjusted(DayAdjust.adjust(input(continuous(), score: 64, temperature: nil, dewPoint: nil))))
        #expect(result.reasons.contains(.noForecast))
        #expect(result.seconds == 3)
    }

    @Test func missingForecastAloneChangesNothing() {
        #expect(DayAdjust.adjust(input(continuous(), score: 80, temperature: nil, dewPoint: nil)) == .none)
    }

    @Test func missingScoreSkipsReadinessStep() throws {
        let expected = Int((WeatherAdjustment.heatFactor(temperature: 27, dewPoint: 22) * 244).rounded())
        let result = try #require(adjusted(DayAdjust.adjust(input(continuous(), score: nil, temperature: 27, dewPoint: 22))))
        #expect(result.seconds == expected)
        #expect(result.reasons == [.heat(temperature: 27, dewPoint: 22, seconds: expected)])
    }

    private func twoBlocks() -> PlannedWorkout {
        PlannedWorkout(id: 3, day: "2026-11-21", title: "Dois blocos", estimatedSeconds: nil, estimatedMeters: nil, steps: [
            PlannedStep(kind: .active, meters: 5_000, target: .pace(fastest: 240, slowest: 248)),
            PlannedStep(kind: .recovery, seconds: 120),
            PlannedStep(kind: .active, meters: 5_000, target: .pace(fastest: 330, slowest: 330)),
        ])
    }

    @Test func heavyLegsAppliesToEveryShape() throws {
        for shape in [DayAdjustShape.continuous, .intervals, .long] {
            let plan = shape == .intervals ? intervals() : continuous()
            let result = try #require(adjusted(DayAdjust.adjust(input(plan, shape: shape, score: 80, heavyLegs: true))))
            #expect(result.seconds == 3)
            #expect(result.reasons == [.heavyLegs(seconds: 3)])
        }
    }

    @Test func capUsesSlowestBlockTotal() {
        let factor = WeatherAdjustment.heatFactor(temperature: 27, dewPoint: 22)
        #expect(Int((factor * 244).rounded()) <= 15)
        #expect(Int((factor * 330).rounded()) > 15)
        let result = DayAdjust.adjust(input(twoBlocks(), score: 80, temperature: 27, dewPoint: 22))
        guard case .swap = result else {
            Issue.record("esperava swap, veio \(result)")
            return
        }
    }

    @Test func reportedSecondsMatchSlowestBlock() throws {
        let factor = WeatherAdjustment.heatFactor(temperature: 24, dewPoint: 20)
        let slow = Int((factor * 330).rounded())
        let fast = Int((factor * 244).rounded())
        #expect(slow > fast)
        let result = try #require(adjusted(DayAdjust.adjust(input(twoBlocks(), score: 80, temperature: 24, dewPoint: 20))))
        #expect(result.seconds == slow)
        #expect(pace(result.steps[0])?.0 == 240 + Double(fast))
        #expect(pace(result.steps[2]).map { [$0.0, $0.1] } == [330 + Double(slow), 330 + Double(slow)])
    }

    @Test func nestedGroupDropsInnerRepeat() throws {
        let inner = PlannedStep(kind: .other, repeats: 4, children: [
            PlannedStep(kind: .active, meters: 1_000, target: .pace(fastest: 240, slowest: 248)),
            PlannedStep(kind: .recovery, seconds: 90),
        ])
        let outer = PlannedStep(kind: .other, repeats: 1, children: [inner])
        let plan = PlannedWorkout(id: 4, day: "2026-11-21", title: "Aninhado", estimatedSeconds: nil, estimatedMeters: nil, steps: [outer])
        let result = try #require(adjusted(DayAdjust.adjust(input(plan, shape: .intervals, score: 55))))
        #expect(result.shortened)
        #expect(result.steps[0].children[0].repeats == 3)
        #expect(pace(result.steps[0].children[0].children[0]).map { [$0.0, $0.1] } == [246, 254])
    }

    @Test func singleActiveWithoutGroupIsNotRemoved() throws {
        let plan = PlannedWorkout(id: 5, day: "2026-11-21", title: "Um bloco", estimatedSeconds: nil, estimatedMeters: nil, steps: [
            PlannedStep(kind: .active, meters: 5_000, target: .pace(fastest: 240, slowest: 248)),
        ])
        let result = try #require(adjusted(DayAdjust.adjust(input(plan, shape: .intervals, score: 55))))
        #expect(result.shortened == false)
        #expect(result.steps.count == 1)
        #expect(result.seconds == 6)
    }

    @Test func equalPaceBoundsShiftBoth() throws {
        let plan = PlannedWorkout(id: 6, day: "2026-11-21", title: "Fixo", estimatedSeconds: nil, estimatedMeters: nil, steps: [
            PlannedStep(kind: .active, meters: 5_000, target: .pace(fastest: 300, slowest: 300)),
        ])
        let result = try #require(adjusted(DayAdjust.adjust(input(plan, score: 64))))
        #expect(pace(result.steps[0]).map { [$0.0, $0.1] } == [303, 303])
    }

    @Test func longRunShortensOnlyLastActive() throws {
        let plan = PlannedWorkout(id: 7, day: "2026-11-21", title: "Longão", estimatedSeconds: nil, estimatedMeters: nil, steps: [
            PlannedStep(kind: .active, meters: 10_000, target: .pace(fastest: 300, slowest: 310)),
            PlannedStep(kind: .active, meters: 10_000, target: .pace(fastest: 290, slowest: 300)),
        ])
        let result = try #require(adjusted(DayAdjust.adjust(input(plan, shape: .long, score: 55))))
        #expect(result.steps[0].meters == 10_000)
        #expect(result.steps[1].meters == 8_000)
        #expect(result.shortened)
    }

    @Test func sunAddsToTheHeatOfTheForecast() throws {
        var shaded = input(continuous(), score: 80, temperature: 26, dewPoint: 20)
        var sunny = shaded
        sunny.radiation = 800
        let shade = try #require(adjusted(DayAdjust.adjust(shaded)))
        let sun = try #require(adjusted(DayAdjust.adjust(sunny)))
        #expect(sun.seconds > shade.seconds)
        shaded.hotSessions = 8
        let adapted = try #require(adjusted(DayAdjust.adjust(shaded)))
        #expect(adapted.seconds < shade.seconds)
    }

    @Test func weatherPicksClosestHour() {
        let hours: [(hour: Int, temperature: Double, dewPoint: Double?)] = [(5, 10, 8), (6, 11, 9), (9, 15, nil)]
        #expect(DayAdjust.weather(at: 7, in: hours)?.temperature == 11)
        #expect(DayAdjust.weather(at: 9, in: hours)?.dewPoint == nil)
        #expect(DayAdjust.weather(at: 7, in: []) == nil)
        let tie: [(hour: Int, temperature: Double, dewPoint: Double?)] = [(8, 20, 1), (6, 10, 2)]
        #expect(DayAdjust.weather(at: 7, in: tie)?.temperature == 10)
    }
}
