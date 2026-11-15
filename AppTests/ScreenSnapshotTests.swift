import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

private struct SamplePayload: Codable, Equatable {
    let name: String
    let values: [Double]
}

@MainActor
@Suite struct ScreenSnapshotTests {
    private typealias F = WorkoutDetailFixtures

    private static let today = Day(iso: F.day(F.base))!

    private static func directory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "snapshots-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    @Test func storeWritesAndReadsBack() {
        let store = ScreenSnapshotStore(directory: Self.directory())
        let payload = SamplePayload(name: "Hoje", values: [1.5, 2])

        store.save(payload, for: .today)

        #expect(store.load(SamplePayload.self, for: .today) == payload)
        #expect(store.load(SamplePayload.self, for: .evolution) == nil)
    }

    @Test func storeIgnoresOtherSchemaVersion() {
        let directory = Self.directory()
        ScreenSnapshotStore(directory: directory, version: 1).save(SamplePayload(name: "Hoje", values: []), for: .today)

        #expect(ScreenSnapshotStore(directory: directory, version: 2).load(SamplePayload.self, for: .today) == nil)
    }

    @Test func storeIgnoresCorruptedFile() throws {
        let directory = Self.directory()
        let store = ScreenSnapshotStore(directory: directory)
        store.save(SamplePayload(name: "Hoje", values: []), for: .today)
        try Data("{ quebrado".utf8).write(to: directory.appending(path: "today.json"))

        #expect(store.load(SamplePayload.self, for: .today) == nil)
    }

    @Test func storeIgnoresPayloadOfAnotherShape() {
        let store = ScreenSnapshotStore(directory: Self.directory())
        store.save(SamplePayload(name: "Hoje", values: []), for: .today)

        #expect(store.load([String].self, for: .today) == nil)
    }

    @Test func storeRemovesOneAndAll() {
        let store = ScreenSnapshotStore(directory: Self.directory())
        for kind in ScreenSnapshotKind.allCases { store.save(SamplePayload(name: kind.rawValue, values: []), for: kind) }

        store.remove(.today)
        #expect(store.load(SamplePayload.self, for: .today) == nil)
        #expect(store.load(SamplePayload.self, for: .evolution) != nil)

        store.removeAll()
        for kind in ScreenSnapshotKind.allCases { #expect(store.load(SamplePayload.self, for: kind) == nil) }
    }

    @Test func todayRestoresFromSnapshotBeforeAnyCalculation() async throws {
        let container = try TodayModelTests.store(withRace: true)
        let store = ScreenSnapshotStore(directory: Self.directory())
        let source = TodayModel(container: container, today: Self.today, snapshots: store)
        await source.load()

        let restored = try #require(await TodayModel.restored(container: container, snapshots: store))

        #expect(restored.isLoaded)
        #expect(restored.isStale)
        #expect(restored.today == Self.today)
        #expect(restored.summary.week == source.summary.week)
        #expect(restored.summary.predictions == source.summary.predictions)
        #expect(restored.summary.readiness == source.summary.readiness)
        #expect(restored.summary.raceCountdownDays == source.summary.raceCountdownDays)
        #expect(restored.summary.race.series.map(\.1) == source.summary.race.series.map(\.1))
        #expect(restored.weekRuns == source.weekRuns)
        #expect(restored.lastRun == source.lastRun)
        #expect(restored.readinessSentence == source.readinessSentence)
        #expect(source.isStale == false)
    }

    @Test func todayWithoutSnapshotHasNothingToRestore() async throws {
        let container = try TodayModelTests.store(withRace: false)

        #expect(await TodayModel.restored(container: container, snapshots: ScreenSnapshotStore(directory: Self.directory())) == nil)
    }

    @Test func todayKeepsContentWhileReloading() async throws {
        let model = TodayModel(container: try TodayModelTests.store(withRace: true), today: Self.today)
        await model.load()
        let week = model.summary.week

        let reload = Task { await model.load() }
        await Task.yield()

        #expect(model.isLoaded)
        #expect(model.summary.week == week)
        await reload.value
        #expect(model.summary.week == week)
    }

    @Test func evolutionRestoresFromSnapshotBeforeAnyCalculation() async throws {
        let container = try EvolutionModelTests.store()
        let store = ScreenSnapshotStore(directory: Self.directory())
        let source = EvolutionModel(container: container, today: Self.today, snapshots: store)
        await source.load()

        let restored = try #require(await EvolutionModel.restored(container: container, horizon: .untilRace, snapshots: store))

        #expect(restored.isLoaded)
        #expect(restored.isStale)
        #expect(restored.overall == source.overall)
        #expect(restored.overallSentence == source.overallSentence)
        #expect(restored.period == source.period)
        #expect(Set(restored.cardData.keys) == Set(source.cardData.keys))
        #expect(restored.cardData[.restingHeartRate]?.stats == source.cardData[.restingHeartRate]?.stats)
        #expect(restored.heatmap == source.heatmap)
        #expect(restored.zoneWeeks == source.zoneWeeks)
        #expect(restored.records == source.records)
        #expect(restored.outlook.series.map(\.1) == source.outlook.series.map(\.1))
        #expect(restored.highlight.goalSentence == source.highlight.goalSentence)
    }

    @Test func evolutionKeepsContentWhileReloading() async throws {
        let model = EvolutionModel(container: try EvolutionModelTests.store(), today: Self.today)
        await model.load()
        let overall = model.overall
        let cards = Set(model.cardData.keys)

        let reload = Task { await model.load() }
        await Task.yield()

        #expect(model.isLoaded)
        #expect(model.overall == overall)
        #expect(Set(model.cardData.keys) == cards)
        await reload.value
        #expect(model.overall == overall)
    }

    @Test func evolutionComputesEffortsOncePerLoad() async throws {
        let model = EvolutionModel(container: try EvolutionModelTests.store(), today: Self.today)

        await model.load()

        #expect(model.reportMemo.effortComputations == 1)
        #expect(model.reportMemo.sessionComputations == 1)
    }

    @Test func nextRaceRestoresFromSnapshotBeforeAnyCalculation() async throws {
        let container = try TodayModelTests.store(withRace: true)
        let race = try #require(try container.mainContext.fetch(FetchDescriptor<RaceRecord>()).first)
        let store = ScreenSnapshotStore(directory: Self.directory())
        let source = NextRaceModel(container: container, raceId: race.id, today: Self.today, snapshots: store)
        await source.load()

        let restored = try #require(await NextRaceModel.restored(container: container, raceId: race.id, snapshots: store))

        #expect(restored.isLoaded)
        #expect(restored.isStale)
        #expect(restored.info == source.info)
        #expect(restored.checklist == source.checklist)
        #expect(restored.block == source.block)
        #expect(restored.blockReading == source.blockReading)
        #expect(restored.target == source.target)
        #expect(restored.strategy == source.strategy)
        #expect(restored.taper == source.taper)
        #expect(await NextRaceModel.restored(container: container, raceId: UUID(), snapshots: store) == nil)
    }

    @Test func raceListRestoresFromSnapshotBeforeAnyCalculation() async throws {
        let container = try TodayModelTests.store(withRace: true)
        let store = ScreenSnapshotStore(directory: Self.directory())
        let source = RaceListModel(container: container, today: Self.today, snapshots: store)
        await source.load()

        let restored = try #require(await RaceListModel.restored(container: container, snapshots: store))

        #expect(restored.isLoaded)
        #expect(restored.isStale)
        #expect(restored.upcoming == source.upcoming)
        #expect(restored.completed == source.completed)
        #expect(restored.candidates.map(\.activityId) == source.candidates.map(\.activityId))
        #expect(restored.summaries == source.summaries)
        #expect(!restored.upcoming.isEmpty)
    }

    @Test func clearingTheStoreDropsEveryScreen() async throws {
        let container = try TodayModelTests.store(withRace: true)
        let store = ScreenSnapshotStore(directory: Self.directory())
        await TodayModel(container: container, today: Self.today, snapshots: store).load()
        await RaceListModel(container: container, today: Self.today, snapshots: store).load()

        store.removeAll()

        #expect(await TodayModel.restored(container: container, snapshots: store) == nil)
        #expect(await RaceListModel.restored(container: container, snapshots: store) == nil)
    }
}
