import Foundation
import Storage
import SwiftData
import Sync
import Testing
@testable import trAIning

@MainActor
@Suite struct WorkoutNoticeContentTests {
    private typealias F = WorkoutDetailFixtures

    private static let name = "Tiros 3 x 1 km"

    private static func store(processed: Bool, failures: Int = 0) throws -> ModelContainer {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        for (index, daysAgo) in [0.0, 7, 14].enumerated() {
            let run = F.run(id: Int64(index + 1), daysAgo: daysAgo, meters: 5_900, workoutName: name, structure: F.intervalStructure(tiroSeconds: 245 + daysAgo))
            run.fitProcessed = processed
            run.fitTransientFailures = failures
            context.insert(run)
        }
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: F.day(F.base.addingTimeInterval(-30 * 86_400)), heartRate: 170))
        try context.save()
        return container
    }

    private static func status(_ id: Int64, in container: ModelContainer) -> WorkoutNoticeStatus {
        WorkoutNotice.status(activityId: id, in: ModelContext(container))
    }

    @Test func buildsNoticeForProcessedRunWithScore() throws {
        guard case .ready(let content) = Self.status(1, in: try Self.store(processed: true)) else {
            Issue.record("aviso não ficou pronto")
            return
        }
        #expect(content.activityId == 1)
        #expect(content.title.contains("nota"))
    }

    @Test func waitsWhileFitIsNotProcessed() throws {
        #expect(Self.status(1, in: try Self.store(processed: false)) == .waiting)
    }

    @Test func waitsWhileActivityIsNotSynced() throws {
        #expect(Self.status(99, in: try Self.store(processed: true)) == .waiting)
    }

    @Test func givesUpWhenFitFailedTooManyTimes() throws {
        #expect(Self.status(1, in: try Self.store(processed: false, failures: SyncConstants.maxFitTransientFailures)) == .unavailable)
    }

    @Test func givesUpWhenProcessedRunHasNoScore() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(ActivityRecord(activityId: 5, typeKey: "running", name: "Sem dados", start: F.base, fitProcessed: true))
        try context.save()
        #expect(Self.status(5, in: container) == .unavailable)
    }
}
