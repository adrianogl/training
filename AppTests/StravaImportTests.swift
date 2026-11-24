import Foundation
import GarminAPI
import RemoteSync
import Storage
import SwiftData
import Synchronization
import Testing
import TrainingCore
@testable import trAIning

private final class ImportTransport: HTTPTransport {
    private let replies: Mutex<[(Int, String)]>

    init(_ replies: [(Int, String)]) {
        self.replies = Mutex(replies)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, body) = replies.withLock { $0.isEmpty ? (500, "") : $0.removeFirst() }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private struct NoAuth: StravaWebAuthenticating {
    func authenticate(url: URL) async throws -> URL { url }
}

@MainActor @Suite struct StravaImportTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)
    private let runs = #"{"runs":[{"id":11,"name":"Longão","sportType":"Run","startDate":"2026-10-31T10:00:00Z","startDateLocal":"2026-10-31T07:00:00Z","distanceMeters":6000,"movingSeconds":1800,"elapsedSeconds":1800,"elevationGain":null,"averageHeartRate":150,"maxHeartRate":165,"hasGps":true}]}"#
    private let streams = #"{"streams":{"time":[0,600,1200,1800],"distance":[0,2000,4000,6000],"latlng":[[-19.9,-43.9],[-19.91,-43.9],[-19.92,-43.9],[-19.93,-43.9]],"altitude":[],"heartrate":[140,150,155,160],"cadence":[85,86,87,88],"velocity":[3.3,3.3,3.3,3.3]}}"#

    private let status = #"{"connected":true,"athleteName":"A","format":"B","enabled":true}"#
    private let noticeId = StravaImportConstants.notificationPrefix + "11"

    private func model(_ replies: [(Int, String)]) throws -> (StravaModel, ModelContainer) {
        try model(replies, defaults: UserDefaults(suiteName: "strava-import-\(UUID().uuidString)")!)
    }

    private func model(_ replies: [(Int, String)], defaults: UserDefaults) throws -> (StravaModel, ModelContainer) {
        let container = try TrainingSchema.container(inMemory: true)
        let model = StravaModel(container: container, defaults: defaults, authenticator: NoAuth(), now: { self.now })
        let transport = ImportTransport(replies)
        model.link = { StravaClient(baseURL: URL(string: "https://sync.example.test")!, token: "sessao", transport: transport) }
        return (model, container)
    }

    @Test func importedRunBecomesAProcessedActivityAndLeavesTheList() async throws {
        let (model, container) = try model([(200, runs), (200, streams), (200, runs)])
        var notified: Set<Int64> = []
        model.imported = { notified = $0 }

        let candidates = try await model.runCandidates()
        #expect(try await model.importRuns(candidates) == 1)

        let record = try #require(try container.mainContext.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(record.activityId == StravaActivityId.make(11))
        #expect(record.fitProcessed && record.samplesData != nil)
        #expect(record.activityTrainingLoad != nil)
        #expect(notified == [record.activityId])
        #expect(try await model.runCandidates().isEmpty)
    }

    @Test func ignoredRunDoesNotComeBack() async throws {
        let (model, _) = try model([(200, runs), (200, runs)])

        let candidates = try await model.runCandidates()
        await model.ignore(candidates.map(\.id))

        #expect(candidates.count == 1)
        #expect(try await model.runCandidates().isEmpty)
    }

    @Test func notifiedRunEntersTheNoticesAndLeavesWhenIgnored() async throws {
        let defaults = UserDefaults(suiteName: "strava-import-\(UUID().uuidString)")!
        let (model, _) = try model([(200, status), (200, runs), (200, runs)], defaults: defaults)
        let inbox = NoticeInboxStore(defaults: defaults, now: { self.now })

        await model.refreshStatus()
        await model.notifyNewRuns()

        let entry = try #require(inbox.entries().first)
        #expect(entry.id == noticeId)
        #expect(entry.title == StravaImportText.notificationTitle)
        #expect(entry.link == StravaImportConstants.workoutsLink)
        await model.ignore([11])
        #expect(inbox.entries().isEmpty)
    }

    @Test func importedRunLeavesTheNotices() async throws {
        let defaults = UserDefaults(suiteName: "strava-import-\(UUID().uuidString)")!
        let (model, _) = try model([(200, runs), (200, streams)], defaults: defaults)
        let inbox = NoticeInboxStore(defaults: defaults, now: { self.now })
        inbox.record(id: noticeId, title: StravaImportText.notificationTitle, text: "Longão", link: StravaImportConstants.workoutsLink, at: nil)

        #expect(try await model.importRuns(try await model.runCandidates()) == 1)
        #expect(inbox.entries().isEmpty)
    }
}
