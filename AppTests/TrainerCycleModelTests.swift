import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

private final class TrainerClock: @unchecked Sendable {
    var day: Day

    init(_ day: Day) {
        self.day = day
    }
}

@MainActor
@Suite struct TrainerCycleModelTests {
    private static let monday = Day(iso: "2026-11-16")!

    private static func mondayPlusWeeks(_ weeks: Int) -> Day {
        monday.adding(days: weeks * TrainerConstants.weekdayCount)
    }

    private static let halfMarathon = TrainerTarget(
        kind: .race, name: "Meia de Floripa", date: mondayPlusWeeks(16), distanceMeters: 21_097.5, goalSeconds: 5_940
    )

    private static func makeStore() -> TrainerStore {
        TrainerStore(
            url: FileManager.default.temporaryDirectory.appending(path: "trainer-cycle-\(UUID().uuidString).json"),
            defaults: UserDefaults(suiteName: "trainer-cycle-\(UUID().uuidString)")!
        )
    }

    private static func makeModel(
        clock: TrainerClock, store: TrainerStore = makeStore(), container: ModelContainer? = nil
    ) throws -> TrainerModel {
        TrainerModel(container: try container ?? TrainingSchema.container(inMemory: true), store: store, today: { clock.day })
    }

    private static func makeModel(today: Day) throws -> TrainerModel {
        try makeModel(clock: TrainerClock(today))
    }

    private static func createHalf(_ model: TrainerModel, start: Double = 60_000, peak: Double = 80_000) async {
        await model.createPlan(
            target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], startMeters: start, peakMeters: peak
        )
    }

    @Test func extraDayShowsUntilKeptAndStaysHiddenForThatCycle() async throws {
        let store = Self.makeStore()
        let clock = TrainerClock(Self.mondayPlusWeeks(6))
        let model = try Self.makeModel(clock: clock, store: store)
        let five = TrainerDayPreference(runs: 5, optional: false, offDays: [7], longDay: 6)
        await model.createPlan(
            target: Self.halfMarathon, structure: TrainerEngine.suggestedStructure(five), strength: [], startMeters: 60_000, peakMeters: 80_000,
            dayPreference: five
        )
        await model.endCycle()

        let suggestion = try #require(model.extraDay)
        #expect(suggestion.preference.runs == 6)

        model.keepDays()
        #expect(model.extraDay == nil)
        #expect(try Self.makeModel(clock: clock, store: store).keptDaysCycleEnd == model.cycleReview?.last)
    }

    @Test func endCycleStoresTheDayAndExposesAReview() async throws {
        let model = try Self.makeModel(today: Self.mondayPlusWeeks(6))
        await Self.createHalf(model)
        await model.endCycle()
        #expect(model.plan?.endedOn == Self.mondayPlusWeeks(6))
        #expect(model.cycleEnded)
        #expect(model.cycleReview?.endedEarly == true)
    }

    @Test func creatingTheNextPlanArchivesTheCycleOnce() async throws {
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(6)
        await model.endCycle()
        await Self.createHalf(model, start: 64_000, peak: 86_000)
        #expect(model.cycleSummaries.count == 1)
        #expect(model.plan?.endedOn == nil)
    }

    @Test func cycleWithoutAClosedWeekIsNotArchived() async throws {
        let model = try Self.makeModel(today: Self.mondayPlusWeeks(6))
        await Self.createHalf(model)
        await model.endCycle()
        await Self.createHalf(model)
        #expect(model.cycleSummaries.isEmpty)
    }

    private static func insertRaceRun(_ container: ModelContainer) throws {
        let raceDay = mondayPlusWeeks(16)
        let context = ModelContext(container)
        let run = WorkoutDetailFixtures.run(id: 40, meters: 21_100)
        run.start = Calendar.current.date(from: DateComponents(year: raceDay.year, month: raceDay.month, day: raceDay.day, hour: 8))!
        run.localDay = raceDay.iso
        context.insert(run)
        try context.save()
    }

    @Test func autoAdjustRefreshesTheCycleReview() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock, container: container)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(16).adding(days: 1)
        await model.load()
        #expect(model.cycleReview?.raceSeconds == nil)
        try Self.insertRaceRun(container)
        await model.autoAdjust()
        #expect(model.cycleReview?.raceSeconds == 21_100 * 0.33)
    }

    @Test func planPulledFromSyncGetsAReviewWithItsHistory() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let store = Self.makeStore()
        let clock = TrainerClock(Self.monday)
        let receiver = try Self.makeModel(clock: clock, store: store, container: container)
        await receiver.load()
        let sender = try Self.makeModel(clock: clock, store: store, container: container)
        await Self.createHalf(sender)
        try Self.insertRaceRun(container)
        clock.day = Self.mondayPlusWeeks(16).adding(days: 1)
        receiver.reloadFromStore()
        await receiver.autoAdjust()
        #expect(receiver.plan != nil)
        #expect(receiver.cycleReview?.raceSeconds == 21_100 * 0.33)
    }

    @Test func seenCycleHidesTheBanner() async throws {
        let model = try Self.makeModel(today: Self.mondayPlusWeeks(6))
        await Self.createHalf(model)
        await model.endCycle()
        #expect(model.showsCycleBanner)
        model.markCycleSeen()
        #expect(!model.showsCycleBanner)
    }

    @Test func runningPlanHasNoReviewNorBanner() async throws {
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(6)
        #expect(model.cycleReview == nil)
        #expect(!model.cycleEnded)
        #expect(!model.showsCycleBanner)
        #expect(model.suggestedVolumes() == nil)
    }

    @Test func endingMidwayClosesTheWeekBefore() async throws {
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(6).adding(days: 2)
        await model.endCycle()
        let review = try #require(model.cycleReview)
        #expect(review.last == Self.mondayPlusWeeks(6).adding(days: -1))
        #expect(model.plan?.versions.count == 1)
    }

    @Test func datedPlanAfterTheRaceShowsTheBannerUntilSeen() async throws {
        let clock = TrainerClock(Self.monday)
        let store = Self.makeStore()
        let model = try Self.makeModel(clock: clock, store: store)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(16).adding(days: 1)
        #expect(model.cycleEnded)
        #expect(model.showsCycleBanner)
        model.markCycleSeen()
        #expect(!model.showsCycleBanner)
        let reopened = try Self.makeModel(clock: clock, store: store)
        #expect(!reopened.showsCycleBanner)
    }

    @Test func archivedSummaryCarriesTheCycleNumbers() async throws {
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(16).adding(days: 1)
        let review = try #require(model.cycleReview)
        let volumes = try #require(model.suggestedVolumes())
        #expect(volumes.start == Int((review.suggestedStartMeters / 1_000).rounded()))
        #expect(volumes.peak == Int((review.suggestedPeakMeters / 1_000).rounded()))
        await Self.createHalf(model)
        let summary = try #require(model.cycleSummaries.first)
        #expect(summary.id == review.last.iso)
        #expect(summary.title == TrainerText.targetTitle(Self.halfMarathon))
        #expect(summary.first == review.first)
        #expect(summary.last == review.last)
        #expect(summary.verdict == review.verdict)
        #expect(summary.beforePeakMeters == review.currentPeakMeters)
        #expect(summary.afterPeakMeters == 80_000)
        #expect(summary.resultSeconds == review.raceSeconds)
    }

    @Test func archivedSummaryKeepsTheVolumeOfTheCreatedPlan() async throws {
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(16).adding(days: 1)
        let review = try #require(model.cycleReview)
        #expect(review.suggestedPeakMeters != 55_000)
        await Self.createHalf(model, start: 45_000, peak: 55_000)
        let summary = try #require(model.cycleSummaries.first)
        #expect(summary.beforePeakMeters == review.currentPeakMeters)
        #expect(summary.afterPeakMeters == 55_000)
        let before = TrainerText.kilometersNumber(review.currentPeakMeters)
        #expect(TrainerCycleText.summaryLine(summary) == "Diminuiu de \(before) para 55 km")
    }

    @Test func endedCycleStopsAdjustingThePlan() async throws {
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(6).adding(days: 2)
        await model.endCycle()
        clock.day = Self.mondayPlusWeeks(7)
        await model.autoAdjust()
        await model.load()
        #expect(model.plan?.versions.count == 1)
        #expect(model.cycleReview?.endedEarly == true)
    }

    @Test func runningPlanStillAdjustsAfterAWeek() async throws {
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(7)
        await model.autoAdjust()
        #expect((model.plan?.versions.count ?? 0) > 1)
    }

    @Test func endedCycleLeavesTheTodayCard() async throws {
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(6).adding(days: 1)
        #expect(model.todayRow(for: clock.day) != nil)
        #expect(model.readinessSuggestion(score: 20, factor: nil) != nil)
        await model.endCycle()
        #expect(model.todayRow(for: clock.day) == nil)
        #expect(model.todayRow(for: clock.day.adding(days: 1)) == nil)
        #expect(model.readinessSuggestion(score: 20, factor: nil) == nil)
        #expect(model.row(for: clock.day.iso) != nil)
    }

    @Test func endedCycleOffersItsOwnVolumes() async throws {
        let model = try Self.makeModel(today: Self.mondayPlusWeeks(6))
        await Self.createHalf(model)
        await model.endCycle()
        let review = try #require(model.cycleReview)
        let volumes = try #require(model.cycleVolumes())
        #expect(volumes.start == Int((review.currentStartMeters / 1_000).rounded()))
        #expect(volumes.peak == Int((review.currentPeakMeters / 1_000).rounded()))
    }

    @Test func cycleReviewFollowsTheDay() async throws {
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        #expect(model.cycleReview == nil)
        clock.day = Self.mondayPlusWeeks(16).adding(days: 1)
        #expect(model.cycleReview?.endedEarly == false)
    }

    @Test func cycleReviewFollowsThePlan() async throws {
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(6)
        #expect(model.cycleReview == nil)
        await model.endCycle()
        #expect(model.cycleReview?.endedEarly == true)
        model.deletePlan()
        #expect(model.cycleReview == nil)
    }

    @Test func extendedHistoryStaysOutOfThePlanHistory() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let today = Self.mondayPlusWeeks(20)
        let oldDay = today.adding(days: -130)
        let context = ModelContext(container)
        let old = WorkoutDetailFixtures.run(id: 30, meters: 10_000)
        old.start = Calendar.current.date(from: DateComponents(year: oldDay.year, month: oldDay.month, day: oldDay.day, hour: 12))!
        old.localDay = oldDay.iso
        context.insert(old)
        context.insert(DailyRecord(day: oldDay.iso, readinessScore: 70))
        try context.save()
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock, container: container)
        await Self.createHalf(model)
        clock.day = today
        await model.load()
        #expect(!model.history.runs.contains { $0.activityId == 30 })
        #expect(model.history.readiness[oldDay] == nil)
        #expect(model.cycleHistory.runs.contains { $0.activityId == 30 })
        #expect(model.cycleHistory.readiness[oldDay] == 70)
    }

    @Test func deletingThePlanKeepsThePastCycles() async throws {
        let store = Self.makeStore()
        let clock = TrainerClock(Self.monday)
        let model = try Self.makeModel(clock: clock, store: store)
        await Self.createHalf(model)
        clock.day = Self.mondayPlusWeeks(6)
        await model.endCycle()
        await Self.createHalf(model)
        model.deletePlan()
        #expect(model.cycleSummaries.count == 1)
        #expect(store.cycleSummaries().count == 1)
    }
}
