import Foundation
import SwiftData
import Testing
@testable import Storage

@Suite struct StorageTests {
    @Test @MainActor func insereEBuscaUmDeCadaModelo() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(DailyRecord(day: "2026-01-10", restingHR: 48, readinessScore: 72))
        context.insert(ActivityRecord(activityId: 42, typeKey: "running", name: "Corrida", start: Date(timeIntervalSince1970: 1_000), distance: 10_000, zoneSeconds: [1, 2, 3, 4, 5]))
        context.insert(RaceRecord(name: "Prova", day: "2026-06-01", distance: 21_097, priority: .a))
        context.insert(SyncState(firstLoadCompleted: true))
        try context.save()

        let daily = try context.fetch(FetchDescriptor<DailyRecord>())
        #expect(daily.count == 1)
        #expect(daily[0].day == "2026-01-10")
        #expect(daily[0].restingHR == 48)
        #expect(daily[0].readinessScore == 72)
        #expect(daily[0].readinessPartial == false)

        let activities = try context.fetch(FetchDescriptor<ActivityRecord>())
        #expect(activities.count == 1)
        #expect(activities[0].activityId == 42)
        #expect(activities[0].typeKey == "running")
        #expect(activities[0].distance == 10_000)
        #expect(activities[0].zoneSeconds == [1, 2, 3, 4, 5])
        #expect(activities[0].fitProcessed == false)

        let races = try context.fetch(FetchDescriptor<RaceRecord>())
        #expect(races.count == 1)
        #expect(races[0].name == "Prova")
        #expect(races[0].distance == 21_097)
        #expect(races[0].priority == "A")

        let states = try context.fetch(FetchDescriptor<SyncState>())
        #expect(states.count == 1)
        #expect(states[0].firstLoadCompleted)
        #expect(states[0].lastSync == nil)
    }

    @Test func containerEmArquivoPersisteEntreAberturas() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")

        do {
            let context = ModelContext(try TrainingSchema.container(url: url))
            context.insert(DailyRecord(day: "2026-01-10", restingHR: 48))
            context.insert(ActivityRecord(activityId: 42, typeKey: "running"))
            try context.save()
        }

        let reopened = ModelContext(try TrainingSchema.container(url: url))
        let daily = try reopened.fetch(FetchDescriptor<DailyRecord>())
        #expect(daily.map(\.day) == ["2026-01-10"])
        #expect(daily.first?.restingHR == 48)
        #expect(try reopened.fetch(FetchDescriptor<ActivityRecord>()).map(\.activityId) == [42])
    }

    @Test func schemaCompativelComCloudKit() {
        let schema = Schema(TrainingSchema.models)
        #expect(Set(schema.entities.map(\.name)) == ["DailyRecord", "ActivityRecord", "RaceRecord", "SyncState", "HeartRateZonesRecord"])
        for entity in schema.entities {
            for attribute in entity.attributes {
                #expect(!attribute.options.contains(.unique), "\(entity.name).\(attribute.name)")
            }
            for relationship in entity.relationships {
                #expect(relationship.isOptional, "\(entity.name).\(relationship.name)")
            }
        }
    }
}

@Model private final class UniqueProbe {
    @Attribute(.unique) var key: String = ""
    init(key: String) { self.key = key }
}

private func uniqueAttributes(_ schema: Schema) -> [String] {
    schema.entities.flatMap { entity in
        entity.attributes.filter { $0.options.contains(.unique) }.map { "\(entity.name).\($0.name)" }
    }
}

@Suite struct SchemaRulesTests {
    @Test func uniqueCheckCatchesUniqueAttribute() {
        #expect(uniqueAttributes(Schema([UniqueProbe.self])) == ["UniqueProbe.key"])
        #expect(uniqueAttributes(Schema(TrainingSchema.models)).isEmpty)
    }

    @Test func everyAttributeIsOptionalOrHasDefault() {
        for entity in Schema(TrainingSchema.models).entities {
            for attribute in entity.attributes {
                #expect(attribute.isOptional || attribute.defaultValue != nil, "\(entity.name).\(attribute.name)")
            }
        }
    }

    @Test func fileStoreRoundTripsBlobsAndOptionals() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")
        let blob = Data((0..<200_000).map { UInt8($0 % 251) })
        do {
            let context = ModelContext(try TrainingSchema.container(url: url))
            context.insert(DailyRecord(day: "2026-02-01", hrvLastNight: 61.5, hrvStatus: "BALANCED", sleepSeconds: 27_000, sleepScore: 82, sleepEndGMT: 1_780_000_000_000))
            context.insert(DailyRecord(day: "2026-02-02"))
            context.insert(ActivityRecord(activityId: 7, typeKey: "running", samplesData: blob, routeData: Data([1, 2]), structureData: Data([3])))
            try context.save()
        }

        let reopened = ModelContext(try TrainingSchema.container(url: url))
        let daily = try reopened.fetch(FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.day)]))
        #expect(daily.count == 2)
        #expect(daily[0].hrvLastNight == 61.5 && daily[0].hrvStatus == "BALANCED")
        #expect(daily[0].sleepSeconds == 27_000 && daily[0].sleepScore == 82 && daily[0].sleepEndGMT == 1_780_000_000_000)
        #expect(daily[1].hrvLastNight == nil && daily[1].sleepSeconds == nil && daily[1].sleepEndGMT == nil)
        let activity = try #require(try reopened.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.samplesData == blob)
        #expect(activity.routeData == Data([1, 2]))
        #expect(activity.structureData == Data([3]))
    }
}

@Suite struct TrainingSchemaCloudKitTests {
    @Test func containersDisableCloudKit() throws {
        let memory = try TrainingSchema.container(inMemory: true)
        let url = FileManager.default.temporaryDirectory.appending(path: "training-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try TrainingSchema.container(url: url)

        #expect(String(describing: ModelConfiguration.CloudKitDatabase.none) != String(describing: ModelConfiguration.CloudKitDatabase.automatic))
        for container in [memory, file] {
            let configuration = try #require(container.configurations.first)
            #expect(String(describing: configuration.cloudKitDatabase) == String(describing: ModelConfiguration.CloudKitDatabase.none))
        }
    }
}
