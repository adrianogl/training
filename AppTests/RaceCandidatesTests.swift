import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct RaceCandidatesTests {
    private static let today = Day(iso: WorkoutDetailFixtures.day(WorkoutDetailFixtures.base))!
    private static let candidateId: Int64 = 900

    private static func run(id: Int64, daysAgo: Int, meters: Double, pace: Double, name: String) -> ActivityRecord {
        let day = today.adding(days: -daysAgo)
        let start = WorkoutDetailFixtures.base.addingTimeInterval(-Double(daysAgo) * 86_400)
        return ActivityRecord(
            activityId: id, typeKey: "running", name: name, start: start,
            distance: meters, duration: meters * pace + 20, movingDuration: meters * pace,
            averageHR: 165, fitProcessed: true, localDay: day.iso
        )
    }

    private static func store(withCandidate: Bool = true, registeredRace: Bool = false) throws -> ModelContainer {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        for (index, daysAgo) in [20, 30, 40].enumerated() {
            context.insert(run(id: Int64(100 + index), daysAgo: daysAgo, meters: 10_000, pace: 0.36, name: "Corrida leve"))
        }
        if withCandidate {
            context.insert(run(id: candidateId, daysAgo: 5, meters: 10_050, pace: 0.29, name: "Corrida 10K"))
        }
        if registeredRace {
            context.insert(RaceRecord(name: "Prova cadastrada", day: today.adding(days: -5).iso, distance: 10_000, goalSeconds: nil, priority: .b))
        }
        try context.save()
        return container
    }

    private static func loaded(_ container: ModelContainer) async -> RaceListModel {
        let model = RaceListModel(container: container, today: today)
        await model.load()
        return model
    }

    @Test func candidatesAppearAboveCompleted() async throws {
        let container = try Self.store()
        let race = RaceRecord(name: "Prova antiga", day: Self.today.adding(days: -60).iso, distance: 10_000, goalSeconds: nil, priority: .b)
        container.mainContext.insert(race)
        try container.mainContext.save()

        let model = await Self.loaded(container)

        #expect(model.candidates.map(\.activityId) == [Self.candidateId])
        #expect(model.candidates.first?.name == "Corrida 10K")
        #expect(model.completed.count == 1)
    }

    @Test func confirmMovesToCompleted() async throws {
        let container = try Self.store()
        let model = await Self.loaded(container)
        #expect(model.completed.isEmpty)

        await model.confirm(Self.candidateId)

        #expect(model.candidates.isEmpty)
        #expect(model.completed.count == 1)
        #expect(model.completed.first?.name == "Corrida 10K")
    }

    @Test func declineRemovesRow() async throws {
        let container = try Self.store()
        let model = await Self.loaded(container)

        await model.decline(Self.candidateId)

        #expect(model.candidates.isEmpty)
        #expect(model.completed.isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<RaceRecord>()).isEmpty)
    }

    @Test func failedAnswerKeepsCandidateAndIsRecorded() async throws {
        let container = try Self.store()
        let failing: RaceAnswer = { _, _ in throw CocoaError(.fileWriteUnknown) }
        let model = RaceListModel(container: container, today: Self.today, confirmAnswer: failing, declineAnswer: failing)
        await model.load()

        await model.confirm(Self.candidateId)

        #expect(model.answerFailed)
        #expect(model.candidates.map(\.activityId) == [Self.candidateId])

        await model.decline(Self.candidateId)

        #expect(model.answerFailed)
        #expect(model.candidates.map(\.activityId) == [Self.candidateId])
    }

    @Test func successfulAnswerClearsFailure() async throws {
        let container = try Self.store()
        var shouldFail = true
        let model = RaceListModel(
            container: container, today: Self.today,
            confirmAnswer: { id, context in
                if shouldFail { throw CocoaError(.fileWriteUnknown) }
                try confirmRace(activityId: id, in: context)
            }
        )
        await model.load()
        await model.confirm(Self.candidateId)
        #expect(model.answerFailed)

        shouldFail = false
        await model.confirm(Self.candidateId)

        #expect(!model.answerFailed)
        #expect(model.candidates.isEmpty)
    }

    @Test func sectionHiddenWithoutCandidates() async throws {
        let container = try Self.store(withCandidate: false)

        let model = await Self.loaded(container)

        #expect(model.candidates.isEmpty)
    }

    @Test func syncAutoLinksRegisteredRace() async throws {
        let container = try Self.store(withCandidate: true, registeredRace: true)

        AppModel.runPostSyncWork(container: container, today: Self.today)

        let race = try #require(try container.mainContext.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(race.resultActivityId == Self.candidateId)
    }
}
