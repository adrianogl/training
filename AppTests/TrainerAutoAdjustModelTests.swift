import Foundation
import Insights
import RemoteSync
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

private final class AutoAdjustClock: @unchecked Sendable {
    var day: Day

    init(_ day: Day) {
        self.day = day
    }
}

@MainActor
@Suite struct TrainerAutoAdjustModelTests {
    private static let monday = Day(iso: "2026-11-16")!

    private static let halfMarathon = TrainerTarget(
        kind: .race, name: "Meia de Floripa", date: monday.adding(days: 16 * TrainerConstants.weekdayCount),
        distanceMeters: 21_097.5, goalSeconds: 5_940
    )

    private static func makeStore() -> TrainerStore {
        TrainerStore(
            url: FileManager.default.temporaryDirectory.appending(path: "trainer-auto-\(UUID().uuidString).json"),
            defaults: UserDefaults(suiteName: "trainer-auto-\(UUID().uuidString)")!
        )
    }

    private static func makeModel(clock: AutoAdjustClock, store: TrainerStore) throws -> TrainerModel {
        TrainerModel(container: try TrainingSchema.container(inMemory: true), store: store, today: { clock.day })
    }

    private static func plannedModel(store: TrainerStore = makeStore()) async throws -> (TrainerModel, AutoAdjustClock) {
        let clock = AutoAdjustClock(monday)
        let model = try makeModel(clock: clock, store: store)
        await model.createPlan(
            target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], startMeters: 60_000, peakMeters: 80_000
        )
        clock.day = monday.adding(days: TrainerConstants.weekdayCount)
        return (model, clock)
    }

    @Test func settledAutoAdjustClosesTheEndedWeek() async throws {
        let (model, _) = try await Self.plannedModel()
        let before = try #require(model.plan?.versions.count)
        model.scheduleAutoAdjust()
        await model.settleAutoAdjust()
        #expect(try #require(model.plan?.versions.count) > before)
    }

    @Test func cancelledAutoAdjustKeepsThePlan() async throws {
        let store = Self.makeStore()
        let (model, _) = try await Self.plannedModel(store: store)
        let before = try #require(model.plan?.versions.count)
        model.scheduleAutoAdjust()
        model.cancelAutoAdjust()
        await model.settleAutoAdjust()
        try await Task.sleep(for: .milliseconds(300))
        #expect(model.plan?.versions.count == before)
        #expect(store.load()?.versions.count == before)
    }

    @Test func cancellingWhileSettlingReturnsWithoutANewVersion() async throws {
        let store = Self.makeStore()
        let (model, _) = try await Self.plannedModel(store: store)
        let before = try #require(model.plan?.versions.count)
        model.scheduleAutoAdjust()
        let settling = Task { await model.settleAutoAdjust() }
        await Task.yield()
        model.cancelAutoAdjust()
        await settling.value
        try await Task.sleep(for: .milliseconds(300))
        #expect(model.plan?.versions.count == before)
        #expect(store.load()?.versions.count == before)
    }

    private static func earlyLightModel() throws -> (TrainerModel, Day) {
        var plan = TrainerEngine.create(
            target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], history: TrainerHistory(runs: []),
            today: monday, now: .now, startMeters: 60_000, peakMeters: 80_000
        )
        let start = plan.weeks[2].start
        plan.earlyLightWeeks[start] = .body
        let store = makeStore()
        try store.save(plan)
        return (try makeModel(clock: AutoAdjustClock(monday), store: store), start)
    }

    @Test func earlyLightWeekShowsAsLightInTheStrip() throws {
        let (model, start) = try Self.earlyLightModel()
        let cell = try #require(model.weekCells.first { $0.start == start })
        #expect(cell.isLight)
        #expect(cell.detail == TrainerText.lightCell)
        #expect(model.isLightWeek(start))
        #expect(model.weekCells.first { $0.start == start.adding(days: TrainerConstants.weekdayCount) }?.isLight == false)
    }

    @Test func togglingAnEarlyLightWeekRemovesTheAnticipation() async throws {
        let (model, start) = try Self.earlyLightModel()
        await model.toggleLightWeek(start)
        #expect(model.plan?.earlyLightWeeks.isEmpty == true)
        #expect(model.plan?.lightWeeks.isEmpty == true)
        #expect(model.weekCells.first { $0.start == start }?.isLight == false)
        #expect(!model.isLightWeek(start))
    }

    private static func stalePlanStore() throws -> TrainerStore {
        var plan = TrainerEngine.create(
            target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], history: TrainerHistory(runs: []),
            today: monday, now: .now, startMeters: 60_000, peakMeters: 80_000
        )
        plan.rulesVersion = nil
        let store = makeStore()
        try store.save(plan)
        return store
    }

    @Test func stalePlanIsRefreshedOnceOnLoad() async throws {
        let store = try Self.stalePlanStore()
        let before = try #require(store.load()?.versions.count)
        let model = try Self.makeModel(clock: AutoAdjustClock(Self.monday), store: store)
        await model.load()

        let refreshed = try #require(store.load())
        #expect(refreshed.versions.count == before + 1)
        #expect(TrainerEngine.isRulesRefresh(try #require(refreshed.versions.last).trigger))
        #expect(TrainerEngine.refreshingRules(refreshed, history: TrainerHistory(runs: []), today: Self.monday, now: .now) == nil)

        let reopened = try Self.makeModel(clock: AutoAdjustClock(Self.monday), store: store)
        await reopened.load()
        #expect(store.load()?.versions.count == before + 1)
    }

    @Test func secondDeviceKeepsTheRefreshedPlan() async throws {
        let store = try Self.stalePlanStore()
        let first = try Self.makeModel(clock: AutoAdjustClock(Self.monday), store: store)
        await first.load()
        let synced = try #require(store.load())

        let other = Self.makeStore()
        #expect(other.apply(RemoteTrainerState(data: try Data(contentsOf: store.url), updatedAt: .now)))
        let second = try Self.makeModel(clock: AutoAdjustClock(Self.monday), store: other)
        await second.load()

        #expect(other.load() == synced)
        #expect(other.pending() == nil)
    }
}
