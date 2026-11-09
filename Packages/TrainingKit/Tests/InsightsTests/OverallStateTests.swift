import Foundation
import Narrative
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Insights

private func indicator(_ kind: IndicatorKind, in state: OverallState) throws -> Indicator {
    try #require(state.indicators.first { $0.kind == kind })
}

@Suite struct OverallStateTests {
    @Test func overallVerdictBetterWhenTwoMoreImprove() throws {
        let runs = everyOtherDay(over: 400) { id, offset in
            run(id: id, daysAgo: offset, split5k: 1_500 + Double(offset), vo2max: 52 - 0.01 * Double(offset))
        }
        let context = try makeContext(runs)

        let state = try overallState(context: context, today: fixtureToday)

        #expect(state.indicators.map(\.kind) == [.racePrediction, .vo2max, .fitness, .zone2Pace, .thresholdPace, .monthlyVolume])
        #expect(try indicator(.racePrediction, in: state).trend == .better)
        #expect(try indicator(.vo2max, in: state).trend == .better)
        #expect(try indicator(.fitness, in: state).trend == .same)
        #expect(try indicator(.monthlyVolume, in: state).trend == .same)
        #expect(try indicator(.zone2Pace, in: state).trend == .unknown)
        #expect(state.facts.improved == 2)
        #expect(state.facts.worsened == 0)
        #expect(state.facts.total == 4)
        #expect(state.facts.verdict == .better)
    }

    @Test func overallMarginIgnoresNoise() throws {
        let runs = everyOtherDay(over: 400) { id, offset in
            run(id: id, daysAgo: offset, vo2max: offset > 80 ? 50 : 50.4)
        }
        let context = try makeContext(runs)

        let state = try overallState(context: context, today: fixtureToday)

        let vo2 = try indicator(.vo2max, in: state)
        #expect(abs((vo2.delta ?? 0) - 0.4) < 0.05)
        #expect(vo2.trend == .same)
        #expect(state.facts.verdict == .stable)
    }

    @Test func overallSkipsMissingIndicators() throws {
        let runs = everyOtherDay(over: 400) { id, offset in run(id: id, daysAgo: offset, vo2max: 50) }
        let context = try makeContext(runs)

        let state = try overallState(context: context, today: fixtureToday)

        let prediction = try indicator(.racePrediction, in: state)
        #expect(prediction.today == nil && prediction.delta == nil && prediction.goalGap == nil)
        #expect(prediction.trend == .unknown)
        #expect(try indicator(.thresholdPace, in: state).trend == .unknown)
        #expect(state.facts.total == 3)
        #expect(state.facts.goalGapSeconds == nil)
    }

    @Test func overallGoalGapUsesTargetRace() throws {
        var models: [any PersistentModel] = improvingRuns()
        models.append(race(name: "Prova", inDays: 30, goal: 1_400))
        let context = try makeContext(models)

        let state = try overallState(context: context, today: fixtureToday)

        let prediction = try indicator(.racePrediction, in: state)
        #expect(abs((prediction.goalGap ?? 0) - 100) < 1e-6)
        #expect(abs((state.facts.goalGapSeconds ?? 0) - 100) < 1e-6)
        #expect(abs((state.facts.raceDayGapSeconds ?? 0) - 40) < 5)
    }
}
