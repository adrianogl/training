import Foundation
import Insights
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
}
