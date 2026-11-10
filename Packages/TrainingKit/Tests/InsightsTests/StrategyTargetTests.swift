import Foundation
import Metrics
import Projections
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Insights

@Suite struct StrategyTargetTests {
    private func outlook(today: Double?, raceDay: (Day, Double)?, goal: Double?) -> RaceOutlook {
        RaceOutlook(
            distance: 21_097.5,
            label: "21,1 km",
            today: today,
            raceDay: raceDay.map { ProjectionPoint(day: $0.0, mid: $0.1, low: $0.1 - 60, high: $0.1 + 60) },
            yearAgo: nil,
            series: [],
            projection: [],
            goalSeconds: goal,
            goalCrossing: goal == nil ? .noGoal : .unreachable,
            assessment: nil
        )
    }

    @Test func strategyTargetsRaceDayProjection() throws {
        let prova = race(name: "Prova", inDays: 30, distance: 21_097.5, goal: 6_300)
        let context = try makeContext([prova])
        let raceDay = fixtureToday.adding(days: 30)

        let target = try #require(try strategyTarget(
            race: prova, outlook: outlook(today: 6_500, raceDay: (raceDay, 6_370), goal: 6_300), today: fixtureToday, context: context
        ))

        #expect(target == StrategyTarget(seconds: 6_370, source: .raceDayProjection, frozenOn: nil))
        #expect(prova.frozenTargetSeconds == nil)
    }

    @Test func strategyFallsBackToTodayThenGoal() throws {
        let prova = race(name: "Prova", inDays: 30, distance: 21_097.5, goal: 6_300)
        let context = try makeContext([prova])

        let fromToday = try strategyTarget(race: prova, outlook: outlook(today: 6_500, raceDay: nil, goal: 6_300), today: fixtureToday, context: context)
        let fromGoal = try strategyTarget(race: prova, outlook: outlook(today: nil, raceDay: nil, goal: 6_300), today: fixtureToday, context: context)
        prova.goalSeconds = nil
        let none = try strategyTarget(race: prova, outlook: outlook(today: nil, raceDay: nil, goal: nil), today: fixtureToday, context: context)

        #expect(fromToday == StrategyTarget(seconds: 6_500, source: .todayPrediction, frozenOn: nil))
        #expect(fromGoal == StrategyTarget(seconds: 6_300, source: .goal, frozenOn: nil))
        #expect(none == nil)
    }

    @Test func strategyFreezesOnEve() throws {
        let prova = race(name: "Prova", inDays: 1, distance: 21_097.5, goal: 6_300)
        let context = try makeContext([prova])
        let raceDay = fixtureToday.adding(days: 1)

        let early = try strategyTarget(
            race: prova, outlook: outlook(today: 6_500, raceDay: (raceDay, 6_380), goal: 6_300),
            today: fixtureToday.adding(days: -1), context: context
        )
        #expect(early?.source == .raceDayProjection)
        #expect(prova.frozenTargetSeconds == nil)

        let eve = try strategyTarget(race: prova, outlook: outlook(today: 6_500, raceDay: (raceDay, 6_370), goal: 6_300), today: fixtureToday, context: context)
        let later = try strategyTarget(race: prova, outlook: outlook(today: 6_400, raceDay: (raceDay, 6_200), goal: 6_300), today: raceDay, context: context)

        #expect(eve == StrategyTarget(seconds: 6_370, source: .frozen, frozenOn: fixtureToday))
        #expect(later == StrategyTarget(seconds: 6_370, source: .frozen, frozenOn: fixtureToday))
        #expect(prova.frozenTargetSeconds == 6_370)
        #expect(prova.frozenTargetDay == fixtureToday.iso)
        #expect(!context.hasChanges)
    }

    @Test func strategyDoesNotFreezeAfterRace() throws {
        let prova = race(name: "Prova", inDays: -3, distance: 21_097.5, goal: 6_300)
        let context = try makeContext([prova])

        let target = try strategyTarget(race: prova, outlook: outlook(today: 6_500, raceDay: nil, goal: 6_300), today: fixtureToday, context: context)

        #expect(target?.source == .todayPrediction)
        #expect(prova.frozenTargetSeconds == nil)
    }

    @Test func outlookForSpecificRaceMatchesTargetOutlook() throws {
        var models: [any PersistentModel] = improvingRuns()
        models.append(race(name: "Prova", inDays: 30, goal: 1_400))
        let context = try makeContext(models)

        let target = try raceOutlook(context: context, today: fixtureToday)
        let efforts = try raceEfforts(context: context, today: fixtureToday)
        let specific = raceOutlook(distance: 5_000, raceDay: fixtureToday.adding(days: 30), goalSeconds: 1_400, efforts: efforts, today: fixtureToday)

        #expect(specific.raceDay == target.raceDay)
        #expect(specific.today == target.today)
        #expect(specific.assessment == target.assessment)
    }
}
