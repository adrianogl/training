import Foundation
import Insights
import Metrics
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct NextRaceModelTests {
    private typealias F = WorkoutDetailFixtures

    private static let today = Day(iso: F.day(F.base))!

    static func syntheticGPX(meters: Double, climbEvery: Double = 4_000) -> Data {
        let metersPerDegree = 111_195.0
        let points = stride(from: 0.0, through: meters, by: 100).map { distance in
            let latitude = -23.5 + distance / metersPerDegree
            let altitude = 750 + 20 * sin(distance / climbEvery * 2 * .pi)
            return "<trkpt lat=\"\(latitude)\" lon=\"-46.6\"><ele>\(altitude)</ele></trkpt>"
        }
        let xml = "<?xml version=\"1.0\"?><gpx version=\"1.1\"><trk><trkseg>\(points.joined())</trkseg></trk></gpx>"
        return Data(xml.utf8)
    }

    private static func emptyStore(_ race: RaceRecord) throws -> ModelContainer {
        let container = try TrainingSchema.container(inMemory: true)
        container.mainContext.insert(race)
        try container.mainContext.save()
        return container
    }

    @Test func infeasibleManualPacesOfferClear() async throws {
        let race = RaceRecord(
            name: "Meia sintética", day: Self.today.adding(days: 20).iso, distance: 21_097.5,
            goalSeconds: 6_360, priority: .a, gpxData: Self.syntheticGPX(meters: 21_200)
        )
        race.manualPaces = Dictionary(uniqueKeysWithValues: (0..<20).map { ($0, 600.0) })
        let container = try Self.emptyStore(race)

        let model = NextRaceModel(container: container, raceId: race.id, today: Self.today)
        await model.load()

        #expect(model.target == StrategyTarget(seconds: 6_360, source: .goal, frozenOn: nil))
        #expect(model.strategyState == .infeasible)
        #expect(model.strategy.isEmpty)

        model.clearManualPaces()

        #expect(model.strategyState == .ok)
        #expect(model.strategy.count == 22)
        #expect(model.strategy.contains { $0.grade != 0 })
        let total = model.strategy.reduce(0) { $0 + $1.pace * ($1.index == 21 ? 0.0975 : 1) }
        #expect(abs(total - 6_360) < 1)
        let stored = try container.mainContext.fetch(FetchDescriptor<RaceRecord>()).first
        #expect(stored?.manualPacesData == nil)
    }

    @Test func manualPaceIsStoredAndOthersAdjust() async throws {
        let race = RaceRecord(name: "10 km", day: Self.today.adding(days: 20).iso, distance: 10_000, goalSeconds: 3_000, priority: .b)
        let container = try Self.emptyStore(race)
        let model = NextRaceModel(container: container, raceId: race.id, today: Self.today)
        await model.load()

        model.setManualPace(330, at: 4)

        let fixed = try #require(model.strategy.first { $0.index == 4 })
        #expect(fixed.manual && fixed.pace == 330)
        #expect(abs(model.strategy.reduce(0) { $0 + $1.pace } - 3_000) < 0.01)
        let stored = try container.mainContext.fetch(FetchDescriptor<RaceRecord>()).first
        #expect(stored?.manualPaces == [4: 330])
    }

    @Test func noGPXGivesFlatStrategy() async throws {
        let race = RaceRecord(name: "10 km", day: Self.today.adding(days: 20).iso, distance: 10_000, goalSeconds: 3_000, priority: .b)
        let container = try Self.emptyStore(race)

        let model = NextRaceModel(container: container, raceId: race.id, today: Self.today)
        await model.load()

        #expect(model.strategyState == .noGPX)
        #expect(model.strategy.count == 10)
        #expect(model.strategy.allSatisfy { $0.grade == 0 })
        #expect(model.strategy[0].pace > model.strategy[5].pace)
        #expect(model.strategy[9].pace < model.strategy[5].pace)
        #expect(model.profile == nil)
    }

    @Test func strategyUsesRaceDayProjectionWithData() async throws {
        let container = try TodayModelTests.store(withRace: true)
        let race = try #require(try container.mainContext.fetch(FetchDescriptor<RaceRecord>()).first)

        let model = NextRaceModel(container: container, raceId: race.id, today: Self.today)
        await model.load()

        let raceDay = try #require(model.outlook.raceDay)
        #expect(model.target == StrategyTarget(seconds: raceDay.mid, source: .raceDayProjection, frozenOn: nil))
        #expect(model.block.count == 12)
        #expect(model.block.contains { $0.projected })
        #expect(model.checklist.map(\.kind) == [.vo2max, .longRun, .thresholdPace, .hrv, .raceDayForm])
        #expect(!model.blockReading.isEmpty)
    }

    @Test func completedRaceShowsResultVsGoalVsEve() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let run = F.run(id: 900, daysAgo: 10, meters: 10_000)
        let other = F.run(id: 901, daysAgo: 20, meters: 10_000)
        context.insert(run)
        context.insert(other)
        let raceDay = Day(iso: run.localDay!)!
        let otherDay = Day(iso: other.localDay!)!
        let linked = RaceRecord(
            name: "10 km da cidade", day: raceDay.iso, distance: 10_000, goalSeconds: 3_270, priority: .a,
            resultActivityId: 900, frozenTargetSeconds: 3_350, frozenTargetDay: raceDay.adding(days: -1).iso
        )
        let unlinked = RaceRecord(name: "Outro dia", day: otherDay.iso, distance: 10_200, goalSeconds: 3_300, priority: .c)
        context.insert(linked)
        context.insert(unlinked)
        try context.save()

        let model = RaceListModel(container: container, today: Self.today)
        await model.load()

        let summary = try #require(model.summaries[linked.id])
        #expect(summary.resultSeconds == 3_300)
        #expect(summary.goalSeconds == 3_270)
        #expect(summary.eveSeconds == 3_350)
        #expect(summary.resultIsSuggestion == false)
        #expect(summary.resultVsGoalText == "+0:30")
        #expect(summary.resultVsEveText == "\(TodayConstants.minusSign)0:50")
        #expect(!summary.lesson.isEmpty)

        let suggested = try #require(model.summaries[unlinked.id])
        #expect(suggested.resultSeconds == 3_300)
        #expect(suggested.resultIsSuggestion)
        #expect(suggested.resultActivityId == 901)
        #expect(suggested.eveSeconds == nil)
        #expect(suggested.eveNote == RacesConstants.noEvePrediction)

        #expect(model.completed.map(\.id).sorted() == [linked.id, unlinked.id].sorted())
        #expect(model.upcoming.isEmpty)
    }

    @Test func pickedActivityLinksAndUnlinks() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let short = F.run(id: 900, daysAgo: 10, meters: 10_000)
        let dayBefore = F.run(id: 902, daysAgo: 11, meters: 21_000)
        let farAway = F.run(id: 903, daysAgo: 30, meters: 21_000)
        [short, dayBefore, farAway].forEach(context.insert)
        let raceDay = Day(iso: short.localDay!)!
        let half = RaceRecord(name: "Meia", day: raceDay.iso, distance: 21_097.5, goalSeconds: 6_300, priority: .a)
        context.insert(half)
        try context.save()

        let model = RaceListModel(container: container, today: Self.today)
        await model.load()
        #expect(model.summaries[half.id]?.resultActivityId == nil)

        let options = await model.resultOptions(for: half.id)
        #expect(Set(options.map(\.activityId)) == [900, 902])

        model.linkResult(raceId: half.id, activityId: 902)
        await model.load()
        let linked = try #require(model.summaries[half.id])
        #expect(linked.resultActivityId == 902)
        #expect(linked.resultIsSuggestion == false)
        #expect(linked.resultSeconds == 21_000 * 0.33)
        #expect(await model.resultOptions(for: half.id).first { $0.activityId == 902 }?.isLinked == true)

        model.unlinkResult(raceId: half.id)
        await model.load()
        #expect(half.resultActivityId == nil)
        #expect(model.summaries[half.id]?.resultActivityId == nil)
        #expect(model.summaries[half.id]?.resultSeconds == nil)
    }
}
