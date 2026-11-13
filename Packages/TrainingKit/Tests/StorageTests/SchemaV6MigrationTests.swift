import Foundation
import SwiftData
import Testing
@testable import Storage

@Suite struct SchemaV6MigrationTests {
    @Test func v5StoreOpensAsV6WithTombstoneFields() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")
        let raceId = UUID()
        let decidedAt = Date(timeIntervalSince1970: 1_800_000_000.5)
        let raceUpdatedAt = Date(timeIntervalSince1970: 1_800_000_100)

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: SchemaV5.self),
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(container)
            context.insert(SchemaV5.ActivityRecord(activityId: 707, fitThresholdHeartRate: 158, watchZoneFloors: [110, 130, 145, 155, 165]))
            context.insert(SchemaV5.RaceRecord(id: raceId, name: "Meia", day: "2026-10-01", distance: 21_097.5, priority: .a, resultActivityId: 707, updatedAt: raceUpdatedAt))
            context.insert(SchemaV5.RaceDecisionRecord(activityId: 707, decision: .notRace, decidedAt: decidedAt))
            context.insert(SchemaV5.SyncState(firstLoadCompleted: true, readinessVersion: 3))
            try context.save()
        }

        let context = ModelContext(try TrainingSchema.container(url: url))
        let race = try #require(try context.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(race.id == raceId)
        #expect(race.name == "Meia")
        #expect(race.resultActivityId == 707)
        #expect(race.updatedAt == raceUpdatedAt)
        #expect(race.deletedAt == nil)
        let decision = try #require(try context.fetch(FetchDescriptor<RaceDecisionRecord>()).first)
        #expect(decision.raceDecision == .notRace)
        #expect(decision.updatedAt == decidedAt)
        #expect(decision.deletedAt == nil)
        let state = try #require(try context.fetch(FetchDescriptor<SyncState>()).first)
        #expect(state.firstLoadCompleted)
        #expect(state.readinessVersion == 3)
        #expect(state.remoteCursor == 0)
        #expect(state.remoteLastPush == nil)
        let activity = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.watchZoneFloors == [110, 130, 145, 155, 165])
    }

    @Test func v6StoreReopensWithTombstones() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")
        let deletedAt = Date(timeIntervalSince1970: 1_800_000_200)
        let push = Date(timeIntervalSince1970: 1_800_000_300)

        do {
            let context = ModelContext(try TrainingSchema.container(url: url))
            context.insert(RaceRecord(name: "Apagada", day: "2026-10-01", distance: 10_000, deletedAt: deletedAt))
            context.insert(RaceDecisionRecord(activityId: 9, decision: .race, updatedAt: push, deletedAt: deletedAt))
            context.insert(SyncState(remoteCursor: 42, remoteLastPush: push))
            try context.save()
        }

        let context = ModelContext(try TrainingSchema.container(url: url))
        #expect(try context.fetch(FetchDescriptor<RaceRecord>()).first?.deletedAt == deletedAt)
        let decision = try #require(try context.fetch(FetchDescriptor<RaceDecisionRecord>()).first)
        #expect(decision.updatedAt == push)
        #expect(decision.deletedAt == deletedAt)
        let state = try #require(try context.fetch(FetchDescriptor<SyncState>()).first)
        #expect(state.remoteCursor == 42)
        #expect(state.remoteLastPush == push)
    }

    @Test func schemaV5IsFrozenWithoutTombstones() {
        let v5 = Schema(versionedSchema: SchemaV5.self)
        let race = Set(v5.entities.first { $0.name == "RaceRecord" }?.attributes.map(\.name) ?? [])
        let decision = Set(v5.entities.first { $0.name == "RaceDecisionRecord" }?.attributes.map(\.name) ?? [])
        let state = Set(v5.entities.first { $0.name == "SyncState" }?.attributes.map(\.name) ?? [])
        #expect(race.contains("manuallyUnlinked"))
        #expect(!race.contains("deletedAt"))
        #expect(decision.contains("decidedAt"))
        #expect(!decision.contains("updatedAt"))
        #expect(!decision.contains("deletedAt"))
        #expect(!state.contains("remoteCursor"))
        #expect(!state.contains("remoteLastPush"))
    }

    @Test func currentSchemaIsV6() {
        let names = Set(Schema(versionedSchema: SchemaV6.self).entities.map(\.name))
        #expect(names == ["DailyRecord", "ActivityRecord", "RaceRecord", "SyncState", "HeartRateZonesRecord", "ThresholdHistoryRecord", "RaceDecisionRecord"])
        #expect(SchemaV6.versionIdentifier == Schema.Version(6, 0, 0))
        #expect(TrainingMigrationPlan.schemas.last.map(ObjectIdentifier.init) == ObjectIdentifier(SchemaV6.self))
        #expect(TrainingSchema.models.count == 7)
    }

    @Test func raceTransferExportSkipsTombstones() throws {
        let kept = RaceRecord(name: "Viva", day: "2026-10-01", distance: 10_000)
        let gone = RaceRecord(name: "Apagada", day: "2026-10-02", distance: 5_000, deletedAt: .now)

        let data = try RaceTransfer.export([kept, gone])

        let file = try JSONDecoder().decode(RaceTransferProbe.self, from: data)
        #expect(file.races.map(\.name) == ["Viva"])
    }

    @Test @MainActor func importNewerThanTombstoneRevivesRace() throws {
        let id = UUID()
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(RaceRecord(id: id, name: "Apagada", day: "2026-10-01", distance: 10_000, updatedAt: Date(timeIntervalSince1970: 1_000), deletedAt: Date(timeIntervalSince1970: 1_000)))
        let data = try RaceTransfer.export([RaceRecord(id: id, name: "Voltou", day: "2026-10-01", distance: 10_000, updatedAt: Date(timeIntervalSince1970: 2_000))])

        _ = try RaceTransfer.importRaces(data, into: context)

        let race = try #require(try context.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(race.name == "Voltou")
        #expect(race.deletedAt == nil)
    }
}

private struct RaceTransferProbe: Decodable {
    struct Item: Decodable { var name: String }
    var races: [Item]
}
