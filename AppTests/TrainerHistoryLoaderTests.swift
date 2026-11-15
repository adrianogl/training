import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerHistoryLoaderTests {
    private typealias F = WorkoutDetailFixtures

    private static let today = Day(iso: F.day(F.base))!

    private static func container() throws -> ModelContainer {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(F.run(id: 1, daysAgo: 1, meters: 8_000))
        context.insert(F.run(id: 2, daysAgo: 3, meters: 11_800, workoutName: "Tiros 3 x 1 km", structure: F.intervalStructure()))
        context.insert(F.run(id: 3, daysAgo: 200, meters: 9_000))
        let ride = F.run(id: 4, daysAgo: 2, meters: 30_000)
        ride.typeKey = "cycling"
        context.insert(ride)
        for (id, daysAgo, name) in [(5, 2.0, "MMII (quarta)"), (6, 9.0, "MMII (quarta)"), (7, 250.0, "Full Body (sexta)")] as [(Int64, Double, String)] {
            let session = F.run(id: id, daysAgo: daysAgo, meters: 0)
            session.typeKey = "strength_training"
            session.name = name
            session.duration = 2_700
            context.insert(session)
        }
        context.insert(DailyRecord(day: today.adding(days: -1).iso, readinessScore: 64))
        context.insert(DailyRecord(day: today.adding(days: -300).iso, readinessScore: 40))
        context.insert(RaceRecord(name: "Meia", day: today.adding(days: 30).iso, distance: 21_097.5, priority: .a))
        try context.save()
        return container
    }

    @Test func loadsOnlyRecentRuns() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        #expect(history.runs.map(\.activityId) == [2, 1])
        #expect(history.runs.first?.meters == 11_800)
        #expect(history.runs.last?.day == Self.today.adding(days: -1))
    }

    @Test func classifiesIntervalRun() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        #expect(history.runs.first { $0.activityId == 2 }?.kind == .intervals)
        #expect(history.runs.first { $0.activityId == 1 }?.kind == .easy)
    }

    @Test func loadsReadinessWithinWindow() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        #expect(history.readiness == [Self.today.adding(days: -1): 64])
    }

    @Test func loadsStrengthSessionsWithinWindow() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        #expect(history.strength.map(\.activityId) == [6, 5])
        #expect(history.strength.allSatisfy { $0.name == "MMII (quarta)" && $0.seconds == 2_700 })
        #expect(history.strength.last?.day == Self.today.adding(days: -2))
        #expect(!history.runs.contains { [5, 6, 7].contains($0.activityId) })
    }

    @Test func detectsTheWeeklySessionFromLoadedStrength() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        let sessions = TrainerEngine.detectStrength(history: history, today: Self.today)
        #expect(sessions.map(\.name) == ["MMII"])
        #expect(sessions.first?.legLoad == .heavy)
    }

    @Test func emptyStoreGivesEmptyHistory() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let history = TrainerHistoryLoader.load(container: container, today: Self.today)
        #expect(history.runs.isEmpty)
        #expect(history.readiness.isEmpty)
        #expect(history.strength.isEmpty)
    }
}
