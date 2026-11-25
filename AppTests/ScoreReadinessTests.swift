import FITReader
import Foundation
import Storage
import SwiftData
import Sync
import Testing
@testable import trAIning

@MainActor
@Suite struct ScoreReadinessTests {
    private typealias F = WorkoutDetailFixtures

    private static let route = try! JSONEncoder().encode([Coordinate(lat: -19.92, lon: -43.94)])

    private static func outdoor(id: Int64 = 1, daysAgo: Double = 0) -> ActivityRecord {
        let record = F.run(id: id, daysAgo: daysAgo, meters: 9_000, workoutName: "Tempo 9 km", structure: F.intervalStructure())
        record.routeData = route
        return record
    }

    @Test func waitsForTheWorkoutFileBeforeTheWeather() {
        let record = Self.outdoor()
        record.fitProcessed = false

        #expect(ScoreReadiness.pending(record, now: F.base) == .workout)
        record.fitTransientFailures = SyncConstants.maxFitTransientFailures
        #expect(ScoreReadiness.pending(record, now: F.base) == nil)
    }

    @Test func outdoorRunWaitsForItsWeatherUntilAnAnswer() {
        let record = Self.outdoor()

        #expect(ScoreReadiness.pending(record, now: F.base) == .weather)
        record.weatherCheckedAt = F.base
        #expect(ScoreReadiness.pending(record, now: F.base) == nil)
    }

    @Test func runsWithoutRouteOrTooOldDoNotWait() {
        let treadmill = F.run(id: 2, meters: 8_000)
        let old = Self.outdoor(id: 3, daysAgo: 121)

        #expect(ScoreReadiness.pending(treadmill, now: F.base) == nil)
        #expect(ScoreReadiness.pending(old, now: F.base) == nil)
    }

    @Test func scoreStoreHoldsTheScoreWhileWeatherIsPending() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        let record = Self.outdoor()
        record.start = .now
        record.scoreValue = 92
        record.scoreKey = "antiga"
        context.insert(record)
        try context.save()

        #expect(ScoreStore.update(in: context, ids: nil))
        #expect(record.scoreValue == nil && record.scoreKey == nil)
        #expect(WorkoutListModel.row(record).scorePending)

        record.weatherCheckedAt = .now
        record.weatherTemperature = 25
        try context.save()
        ScoreStore.update(in: context, ids: nil)
        #expect(record.scoreValue != nil)
        #expect(!WorkoutListModel.row(record).scorePending)
    }
}
