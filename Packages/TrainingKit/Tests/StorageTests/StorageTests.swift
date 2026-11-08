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
        context.insert(RaceRecord(name: "Prova", day: "2026-06-01", distance: 21_097, priority: "A"))
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

    @Test func schemaCompativelComCloudKit() {
        let schema = Schema(TrainingSchema.models)
        #expect(schema.entities.count == 4)
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
