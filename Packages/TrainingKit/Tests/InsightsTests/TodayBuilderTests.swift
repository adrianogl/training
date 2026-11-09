import Foundation
import Metrics
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Insights

@Suite struct TodayBuilderTests {
    @Test func targetRacePrefersNextA() throws {
        let context = try makeContext([
            race(name: "B perto", inDays: 10, priority: .b),
            race(name: "A depois", inDays: 80, priority: .a),
            race(name: "A próxima", inDays: 40, priority: .a),
            race(name: "C passada", inDays: -5, priority: .c),
        ])

        let target = try targetRace(in: context, today: fixtureToday)

        #expect(target?.name == "A próxima")
    }

    @Test func targetRaceSkipsTodayAndPast() throws {
        let context = try makeContext([
            race(name: "A hoje", inDays: 0, priority: .a),
            race(name: "A passada", inDays: -20, priority: .a),
            race(name: "C mais longe", inDays: 30, priority: .c),
            race(name: "B próxima", inDays: 5, priority: .b),
        ])

        let target = try targetRace(in: context, today: fixtureToday)

        #expect(target?.name == "B próxima")
        #expect(try targetRace(in: makeContext(), today: fixtureToday) == nil)
    }

    @Test func weekVolumeCountsOnlyRuns() throws {
        let context = try makeContext([
            run(id: 1, daysAgo: 3, distance: 10_000),
            run(id: 2, daysAgo: 2, distance: 30_000, typeKey: "cycling"),
            run(id: 3, daysAgo: 1, distance: 5_000),
            run(id: 4, daysAgo: 5, distance: 20_000),
            run(id: 5, daysAgo: 9, distance: 12_000),
            run(id: 6, daysAgo: 16, distance: 8_000),
            run(id: 7, daysAgo: 26, distance: 0),
            run(id: 8, daysAgo: 30, distance: 10_000),
            run(id: 9, daysAgo: 40, distance: 99_000),
        ])

        let week = try todaySummary(context: context, today: fixtureToday).week

        #expect(week.perDay[daysAgo(3)] == 10)
        #expect(week.perDay[daysAgo(2)] == 0)
        #expect(week.perDay[daysAgo(1)] == 5)
        #expect(week.perDay[fixtureToday] == 0)
        #expect(week.perDay.count == 4)
        #expect(week.total == 15)
        #expect(week.lastWeek == 32)
        #expect(abs(week.average4Weeks - (32 + 8 + 0 + 10) / 4) < 1e-9)
    }

    @Test func readinessUsesMorningLoadAndSupportNumbers() throws {
        var models: [any PersistentModel] = everyOtherDay(over: 61) { id, offset in run(id: id, daysAgo: offset, load: 60) }
        models.append(run(id: 999, daysAgo: 0, load: 400))
        for offset in 0...30 {
            models.append(daily(daysAgo: offset, hrv: 60, balanced: 50...70, sleepScore: 80, bodyBattery: 70, stress: 25))
        }
        let context = try makeContext(models)

        let summary = try todaySummary(context: context, today: fixtureToday)

        let record = try #require(context.fetch(FetchDescriptor<DailyRecord>()).first { $0.day == fixtureToday.iso })
        let ratio = try #require(summary.supporting.acuteChronic)
        var load: [Day: Double] = [:]
        for offset in stride(from: 61, through: 0, by: -2) { load[daysAgo(offset), default: 0] += 60 }
        #expect(abs(ratio - acuteChronicRatio(dailyLoad: load, on: daysAgo(1))!) < 1e-9)
        let expected = readiness(ReadinessInput(
            hrvLastNight: record.hrvLastNight,
            hrvBaseline: HRVBaseline(lowUpper: 40, balancedLow: 50, balancedUpper: 70),
            sleepScore: 80,
            bodyBatteryMorningMax: 70,
            acuteChronic: ratio
        ))
        #expect(summary.readiness?.score == expected?.score)
        #expect(summary.verdict == expected?.verdict)
        #expect(summary.readiness?.normal != nil)
        #expect(summary.supporting.sleepScore == 80)
        #expect(summary.supporting.stress == 25)
        #expect(summary.supporting.hrvVsBaseline == 0)
        #expect(summary.lastRunId == 999)
        #expect(summary.predictions.count == 4)
    }

    @Test func countdownAndPriorityComeFromTargetRace() throws {
        let context = try makeContext([race(name: "Alvo", inDays: 25, distance: 10_000, priority: .b)])

        let summary = try todaySummary(context: context, today: fixtureToday)

        #expect(summary.raceCountdownDays == 25)
        #expect(summary.racePriority == .b)
        #expect(summary.race.distance == 10_000)
        #expect(summary.race.label == "10 km")
    }
}
