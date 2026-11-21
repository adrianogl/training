import Foundation
import GarminAPI
import Insights
import Storage
import TrainingCore
import Testing
@testable import trAIning

@Suite struct DayAdjustTextTests {
    static let interval = PlannedStep(kind: .active, meters: 1_000, target: .pace(fastest: 240, slowest: 248))
    static let rest = PlannedStep(kind: .rest, seconds: 150)

    static func repeats(_ count: Int, offset: Double = 0) -> PlannedStep {
        var active = interval
        active.target = .pace(fastest: 240 + offset, slowest: 248 + offset)
        return PlannedStep(kind: .other, repeats: count, children: [active, rest])
    }

    static func steps(_ count: Int, offset: Double = 0) -> [PlannedStep] {
        [PlannedStep(kind: .warmup, meters: 3_000), repeats(count, offset: offset), PlannedStep(kind: .cooldown, meters: 2_000)]
    }

    static let plan = PlannedWorkout(id: 1, day: "2026-11-21", title: "Intervalado 5 × 1 km", estimatedSeconds: nil, estimatedMeters: 10_000, steps: steps(5))
    static let heatAndReadiness: [DayAdjustReason] = [.readiness(score: 64, seconds: 3), .heat(temperature: 27, dewPoint: 22, seconds: 7)]
    static let adjusted = DayAdjustResult.adjusted(steps: steps(5, offset: 10), original: steps(5), seconds: 10, reasons: heatAndReadiness, shortened: false)

    @Test func chipsFollowTheMock() {
        #expect(DayAdjustText.chips(Self.heatAndReadiness, hour: 7) == ["calor 27° · orvalho 22° às 7h · +7 s", "prontidão 64 · +3 s"])
        #expect(DayAdjustText.chips([.heavyLegs(seconds: 3), .noForecast], hour: 7) == ["pernas ontem · +3 s", "sem previsão do tempo"])
    }

    @Test func noticeForIntervals() throws {
        let notice = try #require(DayAdjustText.notice(Self.adjusted, shape: .intervals, hour: 7))
        #expect(notice.title == "Ajuste para hoje · +10 s/km nos tiros")
        #expect(notice.text == "Pace recalculado para o calor e a prontidão. Se a FC subir demais mesmo assim, pare um tiro antes.")
        #expect(notice.chips == ["calor 27° · orvalho 22° às 7h · +7 s", "prontidão 64 · +3 s"])
    }

    @Test func noticeForContinuousAndLong() throws {
        let reasons: [DayAdjustReason] = [.readiness(score: 64, seconds: 3), .noForecast, .heavyLegs(seconds: 3)]
        let result = DayAdjustResult.adjusted(steps: [], original: [], seconds: 6, reasons: reasons, shortened: false)
        let continuous = try #require(DayAdjustText.notice(result, shape: .continuous, hour: 7))
        #expect(continuous.title == "Ajuste para hoje · +6 s/km no ritmo")
        #expect(continuous.text == "Pace recalculado para a prontidão e a perna de ontem. Se a FC subir demais mesmo assim, segure o ritmo.")
        let long = try #require(DayAdjustText.notice(result, shape: .long, hour: 7))
        #expect(long.title == "Ajuste para hoje · +6 s/km no longão")
        #expect(long.text.hasSuffix("encurte o final."))
    }

    @Test func noNoticeWithoutAdjust() {
        #expect(DayAdjustText.notice(.none, shape: .intervals, hour: 7) == nil)
        #expect(DayAdjustText.notice(.rest, shape: .intervals, hour: 7) == nil)
    }

    @Test func displayExplainsSwapAndKeepsRestSentence() {
        let swap = DayAdjustText.display(.swap(reasons: [.heat(temperature: 28, dewPoint: 23, seconds: 18)]), plan: Self.plan, hour: 7)
        #expect(swap.notice?.title == "Ajuste para hoje")
        #expect(swap.notice?.text == "O pace subiria mais de 15 s/km por calor: troque por rodagem leve em Z1–Z2 ou descanse.")
        #expect(swap.notice?.chips == ["calor 28° · orvalho 23° às 7h · +18 s"])
        #expect(swap.fallback == nil && swap.original == nil)
        #expect(swap.steps == Self.plan.steps)
        let both = DayAdjustText.display(.swap(reasons: Self.heatAndReadiness + [.noForecast]), plan: Self.plan, hour: 7)
        #expect(both.notice?.text == "O pace subiria mais de 15 s/km por calor e prontidão: troque por rodagem leve em Z1–Z2 ou descanse.")
        #expect(DayAdjustText.display(.rest, plan: Self.plan, hour: 7).fallback == TodayConstants.planAdjustRest[.intervals])
        let none = DayAdjustText.display(.none, plan: Self.plan, hour: 7)
        #expect(none.notice == nil && none.fallback == nil && none.original == nil)
    }

    @Test func morningLine() {
        #expect(DayAdjustText.morning(Self.adjusted, plan: Self.plan) == "Tiros em 4:10–4:18 por calor e prontidão.")
        let three = DayAdjustResult.adjusted(
            steps: Self.steps(5, offset: 13), original: Self.steps(5), seconds: 13,
            reasons: Self.heatAndReadiness + [.heavyLegs(seconds: 3)], shortened: false
        )
        #expect(DayAdjustText.morning(three, plan: Self.plan) == "Tiros em 4:13–4:21 por calor, prontidão e perna de ontem.")
        #expect(DayAdjustText.morning(.none, plan: Self.plan) == nil)
        #expect(DayAdjustText.morning(.swap(reasons: Self.heatAndReadiness), plan: Self.plan) == nil)
        #expect(DayAdjustText.morning(.rest, plan: Self.plan) == nil)
    }

    @Test func wasTextShowsOnlyWhatChanged() {
        var faster = Self.interval
        faster.target = .pace(fastest: 250, slowest: 258)
        #expect(PlanText.was(faster, original: Self.interval) == "era 4:00–4:08")
        #expect(PlanText.was(Self.interval, original: Self.interval) == nil)
        #expect(PlanText.wasRepeats(Self.repeats(4), original: Self.repeats(5)) == "era 5×")
        #expect(PlanText.wasRepeats(Self.repeats(5), original: Self.repeats(5)) == nil)
    }

    @Test func alignsStepsAfterADroppedRepeat() {
        let original = [PlannedStep(kind: .warmup, meters: 3_000), Self.interval, Self.rest, Self.interval, PlannedStep(kind: .cooldown, meters: 2_000)]
        let steps = [original[0], original[1], original[4]]
        let aligned = PlanText.aligned(steps, original: original)
        #expect(aligned == [original[0], original[1], original[4]])
    }

    @Test func morningLineMentionsHeavyLegs() throws {
        let line = try #require(DayAdjustText.morningLine(plan: Self.plan, score: nil, forecast: [], recent: [], heavyLegs: true))
        #expect(line.hasPrefix("Tiros em "))
        #expect(line.hasSuffix("por perna de ontem."))
    }

    @Test func morningLineIsNilWhenTrainerSuggestionIsActive() {
        #expect(DayAdjustText.morningLine(plan: Self.plan, score: nil, forecast: [], recent: [], heavyLegs: true, showsAdvice: false) == nil)
    }

    @Test func pendingRunSkipsTheWorkoutDoneToday() {
        let day = Day(iso: "2026-11-21")!
        let morning = Calendar.current.date(bySettingHour: 5, minute: 30, second: 0, of: day.chartDate)!
        let done = ActivityRecord(activityId: 1, typeKey: "running", name: "Intervalado 5 × 1 km", start: morning)
        let yesterday = ActivityRecord(activityId: 2, typeKey: "running", name: "Intervalado 5 × 1 km", start: morning.addingTimeInterval(-86_400))
        #expect(DayAdjustText.pendingRun([Self.plan], recent: [done], day: day) == nil)
        #expect(DayAdjustText.pendingRun([Self.plan], recent: [yesterday], day: day) == Self.plan)
    }
}
