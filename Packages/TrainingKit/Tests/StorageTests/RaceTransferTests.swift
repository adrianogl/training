import Foundation
import SwiftData
import Testing
@testable import Storage

@Suite struct RaceTransferTests {
    private func makeRace(id: UUID = UUID(), name: String = "Prova", updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000.25)) -> RaceRecord {
        RaceRecord(
            id: id, name: name, day: "2026-06-01", distance: 21_097.5, startTime: "06:30",
            goalSeconds: 5_400, priority: .a, city: "Cidade",
            gpxData: Data([1, 2, 3]), manualPacesData: Data([4, 5]), customLabelsData: Data([6]),
            resultActivityId: 9_000_000_001, updatedAt: updatedAt
        )
    }

    private func export(_ races: [RaceRecord]) throws -> Data { try RaceTransfer.export(races) }

    @Test @MainActor func roundTrip() throws {
        let a = makeRace(name: "A")
        let b = RaceRecord(name: "B", day: "2026-09-01", distance: 10_000, updatedAt: Date(timeIntervalSince1970: 1_700_000_100.5))
        let data = try export([a, b])

        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let result = try RaceTransfer.importRaces(data, into: context)
        #expect(result.inserted == 2)
        #expect(result.updated == 0)
        #expect(result.skipped == 0)

        let fetched = try context.fetch(FetchDescriptor<RaceRecord>())
        for original in [a, b] {
            let copy = try #require(fetched.first { $0.id == original.id })
            #expect(copy.name == original.name)
            #expect(copy.day == original.day)
            #expect(copy.startTime == original.startTime)
            #expect(copy.distance == original.distance)
            #expect(copy.goalSeconds == original.goalSeconds)
            #expect(copy.priority == original.priority)
            #expect(copy.city == original.city)
            #expect(copy.gpxData == original.gpxData)
            #expect(copy.manualPacesData == original.manualPacesData)
            #expect(copy.customLabelsData == original.customLabelsData)
            #expect(copy.resultActivityId == original.resultActivityId)
            #expect(copy.updatedAt == original.updatedAt)
        }
    }

    @Test @MainActor func raceTransferRoundTripsFrozenTarget() throws {
        let race = makeRace(name: "Congelada")
        race.frozenTargetSeconds = 5_321.5
        race.frozenTargetDay = "2026-05-20"
        let data = try export([race])

        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        _ = try RaceTransfer.importRaces(data, into: context)

        let copy = try #require(try context.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(copy.frozenTargetSeconds == 5_321.5)
        #expect(copy.frozenTargetDay == "2026-05-20")
    }

    @Test @MainActor func raceTransferRoundTripsManuallyUnlinked() throws {
        let race = makeRace(name: "Desvinculada")
        race.manuallyUnlinked = true
        let data = try export([race])

        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        _ = try RaceTransfer.importRaces(data, into: context)

        let copy = try #require(try context.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(copy.manuallyUnlinked == true)
    }

    @Test @MainActor func importsFileWithoutFrozenFields() throws {
        let id = UUID()
        let json = """
        {"version":1,"races":[{"id":"\(id.uuidString)","name":"Antiga","day":"2026-06-01","distance":10000,"priority":"B","updatedAt":1700000000}]}
        """
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext

        let result = try RaceTransfer.importRaces(Data(json.utf8), into: context)

        #expect(result.inserted == 1)
        let race = try #require(try context.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(race.id == id)
        #expect(race.frozenTargetSeconds == nil)
        #expect(race.frozenTargetDay == nil)
        #expect(race.manuallyUnlinked == false)
    }

    @Test @MainActor func newerEditWins() throws {
        let id = UUID()
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(makeRace(id: id, name: "Local", updatedAt: Date(timeIntervalSince1970: 1_000)))

        let older = try export([makeRace(id: id, name: "Velha", updatedAt: Date(timeIntervalSince1970: 500))])
        let skipped = try RaceTransfer.importRaces(older, into: context)
        #expect(skipped.skipped == 1)
        #expect(skipped.updated == 0)

        let newer = try export([makeRace(id: id, name: "Nova", updatedAt: Date(timeIntervalSince1970: 2_000))])
        let updated = try RaceTransfer.importRaces(newer, into: context)
        #expect(updated.updated == 1)
        #expect(updated.inserted == 0)

        let fetched = try context.fetch(FetchDescriptor<RaceRecord>())
        #expect(fetched.count == 1)
        #expect(fetched[0].name == "Nova")
        #expect(fetched[0].updatedAt == Date(timeIntervalSince1970: 2_000))
        #expect(fetched[0].gpxData == Data([1, 2, 3]))
    }

    @Test @MainActor func tieOnUpdatedAtIsSkipped() throws {
        let id = UUID()
        let stamp = Date(timeIntervalSince1970: 1_000.75)
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(makeRace(id: id, name: "Local", updatedAt: stamp))

        let data = try export([makeRace(id: id, name: "Arquivo", updatedAt: stamp)])
        let result = try RaceTransfer.importRaces(data, into: context)
        #expect(result.skipped == 1)
        #expect(result.updated == 0)
        #expect(try context.fetch(FetchDescriptor<RaceRecord>())[0].name == "Local")
    }

    @Test @MainActor func rejectsUnknownVersion() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let data = Data(#"{"version":2,"races":[{"id":"\#(UUID().uuidString)"}]}"#.utf8)
        #expect(throws: RaceTransferError.unsupportedVersion(2)) {
            try RaceTransfer.importRaces(data, into: context)
        }
        #expect(try context.fetch(FetchDescriptor<RaceRecord>()).isEmpty)
    }

    @Test @MainActor func malformedJSONThrows() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        #expect(throws: (any Error).self) {
            try RaceTransfer.importRaces(Data("not json".utf8), into: context)
        }
    }
}

@Suite struct RaceTransferEdgeTests {
    @Test @MainActor func duplicateIdInFileKeepsNewest() throws {
        let id = UUID()
        let old = RaceRecord(id: id, name: "Velha", day: "2026-06-01", distance: 10_000, updatedAt: Date(timeIntervalSince1970: 1_000))
        let new = RaceRecord(id: id, name: "Nova", day: "2026-06-01", distance: 10_000, updatedAt: Date(timeIntervalSince1970: 2_000))
        let data = try RaceTransfer.export([new, old])
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext

        let result = try RaceTransfer.importRaces(data, into: context)
        try context.save()

        let races = try context.fetch(FetchDescriptor<RaceRecord>())
        #expect(races.count == 1)
        #expect(races.first?.name == "Nova")
        #expect(result.inserted == 1 && result.skipped == 1)
    }

    @Test @MainActor func unknownPriorityFallsBackToC() throws {
        var item = RaceTransferItem(RaceRecord(name: "Prova", day: "2026-06-01", distance: 10_000, priority: .a))
        item.priority = "Z"
        let file = RaceTransferFile(version: RaceTransferConstants.currentVersion, races: [item])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext

        _ = try RaceTransfer.importRaces(try encoder.encode(file), into: context)

        let race = try #require(try context.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(race.priorityLevel == .c)
        #expect(race.priority == "C")
    }

    @Test func priorityLevelMapsRawValue() {
        let race = RaceRecord(name: "Prova", day: "2026-06-01", distance: 10_000, priority: .b)
        #expect(race.priority == "B")
        race.priorityLevel = .a
        #expect(race.priority == "A")
        race.priority = "x"
        #expect(race.priorityLevel == .c)
    }
}
