import FITReader
import Foundation
import GarminAPI
import RemoteSync
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import HealthImport
@testable import Sync

@Suite struct StravaRunImportTests {
    private let start = Calendar.current.date(byAdding: .hour, value: -30, to: .now)!

    private func run(heartRate: Double? = 150, gps: Bool = true, sport: String = "Run") -> StravaRunCandidate {
        let local = HealthMapping.localString(start).replacingOccurrences(of: " ", with: "T") + "Z"
        return StravaRunCandidate(
            id: 16_123_456_789, name: "Longão", sportType: sport, start: start, startLocal: local, distanceMeters: 6_000, movingSeconds: 1_800,
            elapsedSeconds: 1_820, elevationGain: 40, averageHeartRate: heartRate, maxHeartRate: heartRate.map { $0 + 15 }, hasGps: gps
        )
    }

    private let streams = StravaStreams(
        time: Array(stride(from: 0.0, through: 1_820, by: 1)),
        distance: Array(stride(from: 0.0, through: 1_820, by: 1)).map { $0 * 3.3 },
        latlng: Array(repeating: [-19.9, -43.9], count: 1_821),
        heartrate: Array(repeating: 150, count: 1_821),
        cadence: Array(repeating: 85, count: 1_821),
        velocity: Array(repeating: 3.3, count: 1_821)
    )

    @Test func idCarriesTheStravaMark() {
        let id = StravaActivityId.make(16_123_456_789)
        #expect(StravaActivityId.isStrava(id))
        #expect(StravaActivityId.stravaId(id) == 16_123_456_789)
        #expect(!StravaActivityId.isStrava(21_000_000_000))
    }

    @Test func mappingKeepsWhatStravaHas() {
        let full = StravaRunMapping.activity(run(), resting: 50, maximum: 190)
        let bare = StravaRunMapping.activity(run(heartRate: nil, gps: false), resting: 50, maximum: 190)
        let summary = StravaRunMapping.summary(streams)

        #expect(full.typeKey == "running" && bare.typeKey == "treadmill_running")
        #expect(full.activityTrainingLoad != nil && bare.activityTrainingLoad == nil)
        #expect(full.startTimeLocal == HealthMapping.localString(start))
        #expect(summary.samples.count == 365)
        #expect(summary.samples[10].t == 50 && summary.samples[10].heartRate == 150 && summary.samples[10].cadence == 170)
        #expect(summary.samples[10].distance == 165)
        #expect(summary.route.count == 1_821)
    }

    @Test func importedRunIsProcessedAndGarminTwinWins() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let dto = StravaRunMapping.activity(run(), resting: 50, maximum: 190)
        let engine = SyncEngine(source: StravaRunSource(summaries: [dto.activityId: StravaRunMapping.summary(streams)]), container: container, today: { Day.today() })

        try await engine.importExternalRuns([dto])

        let context = ModelContext(container)
        let imported = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(imported.fitProcessed && imported.samplesData != nil && imported.routeData != nil)
        #expect(imported.processingVersion == FITReaderConstants.processingVersion)

        var garmin = dto
        garmin.activityId = 21_000_000_000
        garmin.distance = 6_100
        try await engine.importExternalRuns([garmin])
        #expect(try await engine.removeStravaTwins() == 1)

        let ids = try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>()).map(\.activityId)
        #expect(ids == [21_000_000_000])
    }
}
