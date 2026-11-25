import Foundation
import GarminAPI
import Testing
import TrainingCore
@testable import Insights

@Suite struct TrainerDayAdjustTests {
    private let day = Day(year: 2026, month: 11, day: 21)

    private func entries(
        score: Int? = 80, temperature: Double? = 12, dewPoint: Double? = 5, hotSessions: Int = 0, heavyLegs: Bool = false
    ) -> DayAdjustEntries {
        DayAdjustEntries(
            day: day, hour: 7, origin: .usual, score: score, temperature: temperature, dewPoint: dewPoint, radiation: nil,
            hotSessions: hotSessions, heavyLegs: heavyLegs, computedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func continuous() -> TrainerWorkout {
        TrainerWorkout(day: day, kind: .threshold, title: "Tempo 13 km", totalMeters: 13_000, steps: [
            TrainerStep(kind: .warmup, meters: 3_000, paceLow: 300, paceHigh: 320),
            TrainerStep(kind: .work, meters: 10_000, paceLow: 240, paceHigh: 248),
        ], paceLow: 240, paceHigh: 248, rationale: "", variant: .continuousTempo)
    }

    private func intervals() -> TrainerWorkout {
        TrainerWorkout(day: day, kind: .vo2max, title: "VO2 8 km", totalMeters: 8_000, steps: [
            TrainerStep(kind: .warmup, meters: 3_000, paceLow: 300, paceHigh: 320),
            TrainerStep(kind: .work, repeats: 5, meters: 1_000, paceLow: 240, paceHigh: 248),
            TrainerStep(kind: .recovery, repeats: 4, meters: 0, restSeconds: 150),
        ], paceLow: 240, paceHigh: 248, rationale: "")
    }

    private func long() -> TrainerWorkout {
        TrainerWorkout(day: day, kind: .long, title: "Longão 18 km", totalMeters: 18_000, steps: [
            TrainerStep(kind: .warmup, meters: 3_000, paceLow: 330, paceHigh: 345),
            TrainerStep(kind: .steady, meters: 12_000, paceLow: 320, paceHigh: 335),
            TrainerStep(kind: .steady, meters: 3_000, paceLow: 290, paceHigh: 300),
        ], paceLow: 320, paceHigh: 335, rationale: "")
    }

    private func adjusted(_ result: TrainerDayAdjustResult) -> TrainerDayAdjustment? {
        guard case let .adjusted(change) = result else { return nil }
        return change
    }

    private func planned(_ workout: TrainerWorkout, id: Int64) -> PlannedWorkout {
        var steps: [PlannedStep] = []
        var index = 0
        while index < workout.steps.count {
            let step = workout.steps[index]
            let target = PlannedTarget.pace(fastest: step.paceLow ?? 0, slowest: step.paceHigh ?? 0)
            switch step.kind {
            case .warmup: steps.append(PlannedStep(kind: .warmup, meters: step.meters, target: target))
            case .work, .steady:
                let active = PlannedStep(kind: .active, meters: step.meters, target: target)
                if step.repeats > 1, index + 1 < workout.steps.count, workout.steps[index + 1].kind == .recovery {
                    let rest = PlannedStep(kind: .recovery, seconds: workout.steps[index + 1].restSeconds)
                    steps.append(PlannedStep(kind: .other, repeats: step.repeats, children: [active, rest]))
                    index += 1
                } else {
                    steps.append(active)
                }
            default: steps.append(PlannedStep(kind: .recovery, meters: step.meters))
            }
            index += 1
        }
        return PlannedWorkout(id: id, day: day.iso, title: workout.title, estimatedSeconds: nil, estimatedMeters: workout.totalMeters, steps: steps)
    }

    @Test func activeStepsShiftWarmupStays() throws {
        let change = try #require(adjusted(TrainerDayAdjust.adjust(continuous(), entries: entries(score: 64))))
        #expect(change.seconds == 3)
        #expect(change.workout.steps[0].paceLow == 300)
        #expect(change.workout.steps[1].paceLow == 243)
        #expect(change.workout.steps[1].paceHigh == 251)
        #expect(change.workout.paceLow == 243)
        #expect(change.original == [TrainerPaceRange(low: 240, high: 248)])
        #expect(change.originalPace == TrainerPaceRange(low: 240, high: 248))
        #expect(change.shortened == false)
        #expect(change.workout.totalMeters == 13_000)
    }

    @Test func heatUsesTheSameShareAsTheCard() throws {
        let change = try #require(adjusted(TrainerDayAdjust.adjust(continuous(), entries: entries(temperature: 27, dewPoint: 22))))
        let expected = Int((WeatherAdjustment.heatFactor(temperature: 27, dewPoint: 22) * 244).rounded())
        #expect(change.seconds == expected)
        #expect(change.workout.steps[1].paceLow == 240 + Double(expected))
    }

    @Test func strongReadinessWithoutHeatIsNone() {
        #expect(TrainerDayAdjust.adjust(continuous(), entries: entries(score: 75)) == .none)
    }

    @Test func lowReadinessIsRest() {
        #expect(TrainerDayAdjust.adjust(continuous(), entries: entries(score: 45)) == .rest)
    }

    @Test func overTheCeilingSwaps() {
        let result = TrainerDayAdjust.adjust(continuous(), entries: entries(score: 55, temperature: 30, dewPoint: 24, heavyLegs: true))
        guard case .swap = result else {
            Issue.record("esperava troca")
            return
        }
    }

    @Test func lowReadinessDropsOneRepeatAndItsRecovery() throws {
        let change = try #require(adjusted(TrainerDayAdjust.adjust(intervals(), entries: entries(score: 55))))
        #expect(change.shortened)
        #expect(change.workout.steps[1].repeats == 4)
        #expect(change.workout.steps[2].repeats == 3)
        #expect(change.workout.totalMeters == 7_000)
        #expect(change.workout.title == "VO2 7 km")
        #expect(change.workout.steps[1].paceLow == 246)
    }

    @Test func singleBlocksDropTheLastWithItsRecovery() throws {
        var workout = intervals()
        workout.steps = [
            TrainerStep(kind: .warmup, meters: 3_000),
            TrainerStep(kind: .work, meters: 2_000, paceLow: 250, paceHigh: 258),
            TrainerStep(kind: .recovery, meters: 400),
            TrainerStep(kind: .work, meters: 2_000, paceLow: 250, paceHigh: 258),
        ]
        workout.totalMeters = 7_400
        workout.title = "Limiar 7,4 km"
        let change = try #require(adjusted(TrainerDayAdjust.adjust(workout, entries: entries(score: 55))))
        #expect(change.workout.steps.count == 2)
        #expect(change.workout.totalMeters == 5_000)
        #expect(change.original.count == 1)
    }

    @Test func continuousScalesActiveDistance() throws {
        let change = try #require(adjusted(TrainerDayAdjust.adjust(continuous(), entries: entries(score: 55))))
        #expect(change.workout.steps[1].meters == 8_000)
        #expect(change.workout.steps[0].meters == 3_000)
        #expect(change.workout.totalMeters == 11_000)
        #expect(change.workout.title == "Tempo 11 km")
    }

    @Test func longShortensOnlyTheLastActive() throws {
        let change = try #require(adjusted(TrainerDayAdjust.adjust(long(), entries: entries(score: 55))))
        #expect(change.workout.steps[1].meters == 12_000)
        #expect(change.workout.steps[2].meters == 2_400)
        #expect(change.workout.totalMeters == 17_400)
        #expect(change.original == [TrainerPaceRange(low: 320, high: 335), TrainerPaceRange(low: 290, high: 300)])
    }

    @Test func cardAndWatchGiveTheSameSeconds() throws {
        let cases: [(TrainerWorkout, DayAdjustShape)] = [(continuous(), .continuous), (intervals(), .intervals), (long(), .long)]
        let inputs = [entries(score: 64, temperature: 26, dewPoint: 20), entries(score: 80, temperature: 29, dewPoint: 22, hotSessions: 4), entries(score: 58, heavyLegs: true)]
        for (workout, shape) in cases {
            for entry in inputs {
                let plan = planned(workout, id: 1)
                let card = DayAdjust.adjust(DayAdjustInput(
                    plan: plan, shape: shape, score: entry.score, temperature: entry.temperature, dewPoint: entry.dewPoint,
                    hotSessions: entry.hotSessions, heavyLegs: entry.heavyLegs, radiation: entry.radiation
                ))
                let watch = TrainerDayAdjust.adjust(workout, entries: entry)
                switch (card, watch) {
                case let (.adjusted(steps, _, seconds, reasons, shortened), .adjusted(change)):
                    #expect(seconds == change.seconds)
                    #expect(reasons == change.reasons)
                    #expect(shortened == change.shortened)
                    let cardPaces = steps.flatMap(\.flattened).filter { $0.kind == .active }.compactMap { step -> Double? in
                        guard case let .pace(fastest, _)? = step.target else { return nil }
                        return fastest
                    }
                    #expect(Set(cardPaces) == Set(change.workout.steps.filter(TrainerDayAdjust.isActive).compactMap(\.paceLow)))
                case (.none, .none), (.rest, .rest), (.swap, .swap): break
                default: Issue.record("card \(card) e relógio \(watch) divergem")
                }
            }
        }
    }

    @Test func smallChangesDoNotCount() throws {
        let base = TrainerDayAdjust.adjust(continuous(), entries: entries(score: 64))
        let same = TrainerDayAdjust.adjust(continuous(), entries: entries(score: 62))
        let bigger = TrainerDayAdjust.adjust(continuous(), entries: entries(score: 64, temperature: 28, dewPoint: 22))
        let shorter = TrainerDayAdjust.adjust(continuous(), entries: entries(score: 55))
        #expect(!TrainerDayAdjust.differs(base, same))
        #expect(TrainerDayAdjust.differs(base, bigger))
        #expect(TrainerDayAdjust.differs(base, shorter))
        #expect(TrainerDayAdjust.differs(.none, base))
        #expect(TrainerDayAdjust.differs(.none, .rest))
        #expect(!TrainerDayAdjust.differs(.none, .none))
    }

    @Test func includedHeatShareOnlyWhenHeatWasApplied() {
        let hot = entries(temperature: 28, dewPoint: 22)
        let result = TrainerDayAdjust.adjust(continuous(), entries: hot)
        #expect(TrainerDayAdjust.includedHeatShare(result, entries: hot) == TrainerDayAdjust.heatShare(hot))
        #expect(TrainerDayAdjust.heatShare(hot) > 0)
        let mild = entries(score: 64)
        #expect(TrainerDayAdjust.includedHeatShare(TrainerDayAdjust.adjust(continuous(), entries: mild), entries: mild) == 0)
    }

    @Test func entriesRoundTripAsJSON() throws {
        let original = entries(score: 64, temperature: 26, dewPoint: 19)
        let decoded = try JSONDecoder().decode(DayAdjustEntries.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}
