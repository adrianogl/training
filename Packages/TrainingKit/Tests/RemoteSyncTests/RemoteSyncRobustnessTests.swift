import Foundation
import Metrics
import Storage
import SwiftData
import Testing
@testable import RemoteSync

private let keys = try! RemoteKeys(syncKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")
private let base = Date(timeIntervalSince1970: 1_800_000_000)
private let emptyPage = ScriptedTransport.Response.json(200, #"{"records":[],"cursor":1,"hasMore":false}"#)
private let accepted = ScriptedTransport.Response.json(200, #"{"cursor":1,"ignored":[]}"#)

private func engine(_ container: ModelContainer, _ transport: ScriptedTransport) -> RemoteSyncEngine {
    let client = RemoteClient(baseURL: URL(string: "https://sync.example.test")!, keys: keys, transport: transport)
    return RemoteSyncEngine(container: container, client: client, keys: keys, now: { base.addingTimeInterval(3_600) })
}

private func randomBytes(_ count: Int) -> Data {
    var generator = SystemRandomNumberGenerator()
    return Data((0..<count).map { _ in UInt8.random(in: 0...255, using: &generator) })
}

private func syntheticGPX(points: Int) -> Data {
    var text = #"<?xml version="1.0"?><gpx version="1.1" creator="teste"><trk><name>Percurso sintético longo com descrição</name><trkseg>"#
    for index in 0..<points {
        let lat = -23.5 + Double(index) * 0.00001 + sin(Double(index) / 7) * 0.000003
        let lon = -46.6 + Double(index) * 0.00001
        text += #"<trkpt lat="\#(lat)" lon="\#(lon)"><ele>\#(700 + sin(Double(index) / 50) * 20)</ele><time>2026-11-12T10:00:00Z</time><extensions><hr>150</hr></extensions></trkpt>"#
    }
    text += "</trkseg></trk></gpx>"
    return Data(text.utf8)
}

private func remoteRace(_ race: RaceRecord, seq: Int64) -> RemoteRecord {
    RemoteRecord(kind: .race, id: race.id.uuidString, updatedAt: race.updatedAt, deleted: false, payload: try! RemotePayload.seal(race: race, key: keys.payload), seq: seq)
}

private func page(_ records: [RemoteRecord], cursor: Int64) -> ScriptedTransport.Response {
    let encoded = try! RemoteJSON.encoder().encode(records)
    return .json(200, #"{"records":\#(String(data: encoded, encoding: .utf8)!),"cursor":\#(cursor),"hasMore":false}"#)
}

@Suite struct RemoteSyncRobustnessTests {
    @Test func batchesStayUnderBodyLimit() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        for index in 0..<5 {
            context.insert(RaceRecord(name: "Prova \(index)", day: "2026-12-01", distance: 10_000, gpxData: randomBytes(500_000), updatedAt: base))
        }
        try context.save()
        let transport = ScriptedTransport([accepted, accepted, emptyPage])

        let report = try await engine(container, transport).sync()

        #expect(report.pushed == 5)
        #expect(transport.pushBodySizes.count == 2)
        #expect(transport.pushBodySizes.allSatisfy { $0 < RemoteSyncConstants.maxBatchBodyBytes })
        #expect(transport.pushBodies.flatMap { $0 }.count == 5)
    }

    @Test func largeGPXIsSimplifiedBeforeSealing() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        let gpx = syntheticGPX(points: 12_000)
        let race = RaceRecord(name: "Ultra", day: "2026-12-01", distance: 80_000, gpxData: gpx, updatedAt: base)
        context.insert(race)
        try context.save()
        let transport = ScriptedTransport([accepted, emptyPage])

        let report = try await engine(container, transport).sync()

        #expect(report.tooLarge.isEmpty)
        let record = try #require(transport.pushBodies.first?.first)
        let payload = try #require(record["payload"] as? String)
        #expect(payload.utf8.count <= RemoteSyncConstants.maxPayloadCharacters)
        let item = try RemotePayload.openRace(payload, id: race.id.uuidString, key: keys.payload)
        let reduced = try #require(item.gpxData)
        #expect(reduced.count < gpx.count)
        let profile = try gpxProfile(reduced)
        #expect(profile.count <= RemoteSyncConstants.reducedGPXMaxPoints)
        #expect(profile.count > 100)
        #expect(try ModelContext(container).fetch(FetchDescriptor<RaceRecord>()).first?.gpxData == gpx)
    }

    @Test func recordStillTooLargeIsSkippedAndOthersSync() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        let huge = RaceRecord(name: "Arquivo enorme", day: "2026-12-01", distance: 10_000, gpxData: randomBytes(900_000), updatedAt: base)
        let small = RaceRecord(name: "Pequena", day: "2026-12-02", distance: 5_000, updatedAt: base)
        context.insert(huge)
        context.insert(small)
        try context.save()
        let transport = ScriptedTransport([accepted, emptyPage])

        let report = try await engine(container, transport).sync()

        #expect(report.tooLarge == [RemoteRecordKey(kind: .race, id: huge.id.uuidString)])
        #expect(transport.pushBodies.flatMap { $0 }.compactMap { $0["id"] as? String } == [small.id.uuidString])
        #expect(transport.requests.last?.httpMethod == "GET")
    }

    @Test func rejectedBatchIsRetriedOneByOne() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(RaceDecisionRecord(activityId: 1, decision: .race, updatedAt: base))
        context.insert(RaceDecisionRecord(activityId: 2, decision: .race, updatedAt: base.addingTimeInterval(1)))
        try context.save()
        let transport = ScriptedTransport([
            .json(413, "{}"),
            accepted,
            .json(400, "{}"),
            emptyPage,
        ])

        let report = try await engine(container, transport).sync()

        #expect(transport.pushBodies.map(\.count) == [2, 1, 1])
        #expect(report.pushed == 1)
        #expect(report.tooLarge.count == 1)
        #expect(transport.requests.last?.httpMethod == "GET")
    }

    @Test func concurrentSyncsAreSerialized() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let remote = RaceRecord(name: "Remota", day: "2026-12-01", distance: 10_000, updatedAt: base)
        let transport = ScriptedTransport([
            page([remoteRace(remote, seq: 5)], cursor: 5),
            .failure(.timedOut),
        ])
        let sut = engine(container, transport)

        async let first = Result { try await sut.sync() }
        async let second = Result { try await sut.sync() }
        let results = await [first, second]

        #expect(results.filter { (try? $0.get()) != nil }.count == 1)
        #expect(transport.requests.map { $0.url?.query } == ["since=0", "since=5"])
        let stored = try ModelContext(container).fetch(FetchDescriptor<RaceRecord>())
        #expect(stored.map(\.name) == ["Remota"])
        #expect(try ModelContext(container).fetch(FetchDescriptor<SyncState>()).first?.remoteCursor == 5)
    }

    @Test func editDuringNetworkWaitIsNotOverwritten() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let race = RaceRecord(name: "Original", day: "2026-12-01", distance: 10_000, updatedAt: base)
        let setup = ModelContext(container)
        setup.insert(race)
        try setup.save()
        let raceId = race.id
        let remoteNewer = RaceRecord(id: raceId, name: "Do iPad", day: "2026-12-01", distance: 10_000, updatedAt: base.addingTimeInterval(10))
        let userEdit = base.addingTimeInterval(20)
        let transport = ScriptedTransport([accepted, page([remoteRace(remoteNewer, seq: 1)], cursor: 1)]) { request in
            guard request.httpMethod == "GET" else { return }
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.id == raceId })
            descriptor.fetchLimit = 1
            guard let local = try? context.fetch(descriptor).first else { return }
            local.name = "Editada aqui"
            local.updatedAt = userEdit
            try? context.save()
        }
        let sut = engine(container, transport)
        _ = try await sut.sync()

        let stored = try #require(try ModelContext(container).fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(stored.name == "Editada aqui")
        #expect(stored.updatedAt == userEdit)
    }

    @Test func pushOverlapsLastPushByFiveSeconds() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(SyncState(remoteLastPush: base))
        context.insert(RaceDecisionRecord(activityId: 1, decision: .race, updatedAt: base.addingTimeInterval(-3)))
        context.insert(RaceDecisionRecord(activityId: 2, decision: .race, updatedAt: base.addingTimeInterval(-6)))
        try context.save()
        let transport = ScriptedTransport([accepted, emptyPage])

        _ = try await engine(container, transport).sync()

        #expect(transport.pushBodies.flatMap { $0 }.compactMap { $0["id"] as? String } == ["1"])
    }

    @Test func quotaExceededStopsPushButStillPulls() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let setup = ModelContext(container)
        setup.insert(SyncState(remoteLastPush: base))
        setup.insert(RaceDecisionRecord(activityId: 1, decision: .race, updatedAt: base.addingTimeInterval(10)))
        setup.insert(RaceDecisionRecord(activityId: 2, decision: .race, updatedAt: base.addingTimeInterval(20)))
        try setup.save()
        let remote = RaceRecord(name: "Remota", day: "2026-12-01", distance: 10_000, updatedAt: base)
        let transport = ScriptedTransport([.json(413, #"{"error":"quota_exceeded"}"#), page([remoteRace(remote, seq: 3)], cursor: 3)])

        let report = try await engine(container, transport).sync()

        #expect(report.quotaExceeded)
        #expect(report.pushed == 0)
        #expect(transport.pushBodies.count == 1)
        #expect(try ModelContext(container).fetch(FetchDescriptor<RaceRecord>()).map(\.name) == ["Remota"])
        let state = try #require(try ModelContext(container).fetch(FetchDescriptor<SyncState>()).first)
        #expect(state.remoteCursor == 3)
        #expect(state.remoteLastPush == base)
    }
}
