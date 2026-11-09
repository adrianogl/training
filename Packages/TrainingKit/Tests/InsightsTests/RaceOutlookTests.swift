import Foundation
import Metrics
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Insights

@Suite struct RaceOutlookTests {
    @Test func raceOutlookCrossingAfterRace() throws {
        var models: [any PersistentModel] = improvingRuns()
        models.append(race(name: "Prova", inDays: 30, goal: 1_400))
        let context = try makeContext(models)

        let outlook = try raceOutlook(context: context, today: fixtureToday)

        let raceDay = try #require(outlook.raceDay)
        #expect(raceDay.day == fixtureToday.adding(days: 30))
        #expect(abs(raceDay.mid - 1_440) < 5)
        #expect(outlook.projection.last?.day == raceDay.day)
        guard case .on(let day) = outlook.goalCrossing else {
            Issue.record("esperava cruzamento, veio \(outlook.goalCrossing)")
            return
        }
        #expect(day > raceDay.day)
        #expect(abs(fixtureToday.days(until: day) - 50) <= 2)
        #expect(outlook.goalSeconds == 1_400)
        #expect(outlook.assessment == .challenging)
        #expect(abs((outlook.today ?? 0) - 1_500) < 1e-6)
        #expect(outlook.series.last?.0 == fixtureToday)
    }

    @Test func raceOutlookAlreadyBeaten() throws {
        var models: [any PersistentModel] = improvingRuns()
        models.append(race(name: "Prova", inDays: 30, goal: 1_550))
        let context = try makeContext(models)

        let outlook = try raceOutlook(context: context, today: fixtureToday)

        #expect(outlook.goalCrossing == .alreadyBeaten)
        #expect(outlook.assessment == .easy)
    }

    @Test func raceOutlookUnreachable() throws {
        var models: [any PersistentModel] = improvingRuns(todaySplit: 1_500, slopePerDay: -2)
        models.append(race(name: "Prova", inDays: 30, goal: 1_200))
        let context = try makeContext(models)

        let outlook = try raceOutlook(context: context, today: fixtureToday)

        #expect(outlook.goalCrossing == .unreachable)
        #expect(outlook.assessment == .aggressive)
    }

    @Test func raceOutlookWithoutRaceUsesHalf() throws {
        let context = try makeContext(improvingRuns(over: 400))

        let outlook = try raceOutlook(context: context, today: fixtureToday)

        #expect(outlook.distance == 21_097.5)
        #expect(outlook.label == "21,1 km")
        #expect(outlook.goalSeconds == nil)
        #expect(outlook.goalCrossing == .noGoal)
        #expect(outlook.raceDay == nil)
        #expect(outlook.assessment == nil)
        #expect(!outlook.projection.isEmpty)
        #expect(abs((outlook.today ?? 0) - riegel(seconds: 1_500, from: 5_000, to: 21_097.5)) < 1e-6)
        #expect(abs((outlook.yearAgo ?? 0) - riegel(seconds: 1_500 + 2 * 366, from: 5_000, to: 21_097.5)) < 1e-6)
    }

    @Test func chunkedSeriesMatchesPredictionSeries() {
        let efforts = (0..<200).map { index in
            Effort(
                distance: index.isMultiple(of: 3) ? 1_000 : 5_000,
                seconds: index.isMultiple(of: 3) ? 280 + Double(index % 11) : 1_450 + Double(index % 37) * 7,
                day: daysAgo(index * 2),
                kind: index.isMultiple(of: 3) ? .split1k : .split5k
            )
        }

        let chunked = chunkedPredictionSeries(distance: 10_000, efforts: efforts, from: daysAgo(365), to: fixtureToday)
        let plain = predictionSeries(distance: 10_000, efforts: efforts, from: daysAgo(365), to: fixtureToday)

        #expect(chunked.map(\.0) == plain.map(\.0))
        #expect(chunked.map(\.1) == plain.map(\.1))
    }
}

@Suite struct LongProjectionTests {
    @Test func longProjectionCoversGoalHorizon() throws {
        var models: [any PersistentModel] = improvingRuns()
        models.append(race(name: "Prova", inDays: 30, goal: 1_400))
        let context = try makeContext(models)

        let outlook = try raceOutlook(context: context, today: fixtureToday)

        #expect(outlook.longProjection.count == 365)
        #expect(outlook.projection.count == 30)
        #expect(outlook.longProjection.prefix(30).map(\.day) == outlook.projection.map(\.day))
    }

    @Test func longProjectionEmptyWithoutData() throws {
        let outlook = try raceOutlook(context: try makeContext(), today: fixtureToday)
        #expect(outlook.longProjection.isEmpty)
    }
}
