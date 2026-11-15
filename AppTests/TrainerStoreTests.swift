import Foundation
import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerStoreTests {
    private static let day = Day(iso: "2026-11-16")!

    private static func store() -> TrainerStore {
        let url = FileManager.default.temporaryDirectory.appending(path: "trainer-\(UUID().uuidString).json")
        let defaults = UserDefaults(suiteName: "trainer-\(UUID().uuidString)")!
        return TrainerStore(url: url, defaults: defaults)
    }

    static func plan() -> TrainerPlan {
        let workout = TrainerWorkout(
            day: day, kind: .threshold, title: "Limiar 3 × 2 km", totalMeters: 11_800,
            steps: [
                TrainerStep(kind: .warmup, meters: 3_000),
                TrainerStep(kind: .work, repeats: 3, meters: 2_000, paceLow: 254, paceHigh: 260),
                TrainerStep(kind: .recovery, repeats: 3, meters: 400),
            ],
            paceLow: 254, paceHigh: 260, note: "rec. 400 m", rationale: "Mantém o volume da semana 1."
        )
        let request = TrainerRequest(category: .travel, text: "Viagem de quinta a domingo", from: day, until: day.adding(days: 3))
        return TrainerPlan(
            target: TrainerTarget(kind: .race, name: "Meia", raceId: UUID(), date: day.adding(days: 90), distanceMeters: 21_097.5, goalSeconds: 5_940),
            structure: TrainerEngine.defaultStructure,
            paces: TrainerPaces(easy: 330, long: 300, threshold: 255, vo2max: 235, race: 281, easyRuns: 12, thresholdRuns: 8, vo2Runs: 7),
            weeks: [TrainerWeek(index: 1, start: day, phase: .base, isRecovery: false, plannedMeters: 52_000, longMeters: 16_000, thresholdFocus: "3 × 2 km", vo2Focus: "5 × 1000 m")],
            workouts: [workout],
            versions: [
                TrainerVersion(number: 1, createdAt: Date(timeIntervalSince1970: 1_793_000_000), trigger: .created, summary: "Plano criado.", changes: []),
                TrainerVersion(
                    number: 2, createdAt: Date(timeIntervalSince1970: 1_793_100_000), trigger: .request(request), summary: "Viagem.",
                    changes: [TrainerChange(kind: .moved, day: day, weekIndex: 1, title: "Limiar", before: "terça", after: "quarta", reason: "Viagem")]
                ),
            ],
            processedActivityIds: [10, 11],
            strength: [TrainerStrengthSession(weekday: 3, group: .lower, legLoad: .heavy, name: "MMII")]
        )
    }

    @Test func savesAndLoadsPlanWithVersionsAndRequest() throws {
        let store = Self.store()
        let plan = Self.plan()
        try store.save(plan)
        #expect(store.load() == plan)
        #expect(store.load()?.strength.first?.name == "MMII")
        let request = TrainerRequest(category: .travel, text: "Viagem de quinta a domingo", from: Self.day, until: Self.day.adding(days: 3))
        #expect(store.load()?.versions.last?.trigger == .request(request))
        try store.delete()
    }

    @Test func loadsPlanSavedBeforeStrengthExisted() throws {
        let store = Self.store()
        try store.save(Self.plan())
        let data = try Data(contentsOf: store.url)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["strength"] = nil
        try JSONSerialization.data(withJSONObject: object).write(to: store.url)
        let loaded = try #require(store.load())
        #expect(loaded.strength.isEmpty)
        #expect(loaded.workouts == Self.plan().workouts)
        try store.delete()
    }

    @Test func remembersStrengthMigration() throws {
        let store = Self.store()
        #expect(!store.strengthMigrated)
        store.markStrengthMigrated()
        #expect(store.strengthMigrated)
        try store.delete()
        #expect(!store.strengthMigrated)
    }

    @Test func deleteRemovesPlanAndSeenVersion() throws {
        let store = Self.store()
        try store.save(Self.plan())
        store.markSeen(2)
        try store.delete()
        #expect(store.load() == nil)
        #expect(store.seenVersion == 0)
    }

    @Test func deleteWithoutFileDoesNotThrow() throws {
        try Self.store().delete()
    }

    @Test func markPendingQueuesTheSavedPlanForPushAgain() throws {
        let store = Self.store()
        try store.save(Self.plan())
        store.markPushed(updatedAt: try #require(store.updatedAt()))
        #expect(store.pending() == nil)

        store.markPending()

        #expect(store.pending() != nil)
    }

    @Test func markPendingWithoutPlanDoesNothing() {
        let store = Self.store()
        store.markPending()
        #expect(store.pending() == nil)
    }

    @Test func loadsNilWhenFileIsCorrupt() throws {
        let store = Self.store()
        try Data("{".utf8).write(to: store.url)
        #expect(store.load() == nil)
        try store.delete()
    }

    private static let summary = TrainerCycleSummary(
        title: "Meia · 16 nov", first: day, last: day.adding(days: 90), verdict: .increase,
        beforePeakMeters: 80_000, afterPeakMeters: 84_000, resultSeconds: 5_880
    )

    @Test func storeIgnoresARepeatedSummary() {
        let store = Self.store()
        store.archive(Self.summary)
        store.archive(Self.summary)
        #expect(store.cycleSummaries() == [Self.summary])
    }

    @Test func archivedSummariesSurviveDeletingThePlan() throws {
        let store = Self.store()
        try store.save(Self.plan())
        store.archive(Self.summary)
        try store.delete()
        #expect(store.cycleSummaries() == [Self.summary])
    }

    @Test func remembersTheLastSeenCycleEnd() {
        let store = Self.store()
        #expect(store.seenCycleEnd == nil)
        store.markCycleSeen(Self.day)
        #expect(store.seenCycleEnd == Self.day)
    }

    @Test func remembersSeenVersion() {
        let store = Self.store()
        #expect(store.seenVersion == 0)
        store.markSeen(3)
        #expect(store.seenVersion == 3)
    }
}
