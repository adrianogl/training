import Foundation
import Narrative
import Storage
import SwiftData
import Testing
import WorkoutAnalysis
@testable import trAIning

private actor CallLog {
    private(set) var count = 0

    func record() {
        count += 1
    }
}

private final class MainThreadFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private func noteIfMainThread(_ flag: MainThreadFlag) {
    if Thread.isMainThread { flag.set() }
}

private struct FakeNarrator: Narrator {
    let log = CallLog()
    let ranOnMainThread = MainThreadFlag()
    var fallsBack = false

    func narrate(_ assessment: WorkoutAssessment, blocks: [WorkoutBlock], evolution: EvolutionFacts?) async -> WorkoutNarrative {
        await log.record()
        noteIfMainThread(ranOnMainThread)
        let template = TemplateNarrator().narrative(assessment, blocks: blocks, evolution: evolution)
        guard !fallsBack, !assessment.orderedFindings.isEmpty || evolution != nil else { return template }
        return WorkoutNarrative(
            findings: assessment.orderedFindings.map { "fake \($0.kind.rawValue)" },
            evolution: evolution.map { _ in "fake evolution" },
            generatedBy: NarrativeConstants.foundationModelsSource,
            factsKey: template.factsKey
        )
    }
}

@MainActor
@Suite struct NarrativeBackfillTests {
    private typealias F = WorkoutDetailFixtures

    private func seed(_ context: ModelContext) throws {
        let name = "Tiros 3 x 1 km"
        context.insert(F.run(id: 1, meters: 5_900, workoutName: name, structure: F.intervalStructure(tiroSeconds: 245)))
        context.insert(F.run(id: 2, daysAgo: 7, meters: 5_900, workoutName: name, structure: F.intervalStructure(tiroSeconds: 250)))
        context.insert(F.run(id: 3, daysAgo: 14, meters: 5_900, workoutName: name, structure: F.intervalStructure()))
        try context.save()
    }

    private func records(_ context: ModelContext) throws -> [ActivityRecord] {
        try context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
    }

    @Test func postSyncHookStoresNarrative() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        try seed(context)
        let narrator = FakeNarrator()

        _ = try await NarrativeBackfill.run(container: container, narrator: narrator, processed: [3], limit: 2)

        let all = try records(context)
        let byId = Dictionary(uniqueKeysWithValues: all.map { ($0.activityId, $0) })
        for id: Int64 in [1, 3] {
            let record = try #require(byId[id])
            let narrative = try JSONDecoder().decode(WorkoutNarrative.self, from: try #require(record.narrativeData))
            let analysis = WorkoutAnalysisContext.build(record: record, records: all, in: context)
            #expect(!analysis.assessment.orderedFindings.isEmpty)
            #expect(narrative.findings.count == analysis.assessment.orderedFindings.count)
            #expect(narrative.factsKey == NarrativeFacts.key(analysis.assessment, blocks: analysis.blocks, evolution: analysis.evolution))
        }
        let first = try JSONDecoder().decode(WorkoutNarrative.self, from: try #require(byId[1]?.narrativeData))
        #expect(first.evolution == "fake evolution")
        #expect(byId[2]?.narrativeData == nil)
        #expect(await narrator.log.count == 2)
    }

    @Test func backfillRunsOffMainActor() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        try seed(container.mainContext)
        let flag = MainThreadFlag()

        _ = try await NarrativeBackfill.run(
            container: container, narrator: FakeNarrator(), processed: [], limit: 10,
            onStep: { noteIfMainThread(flag) }
        )

        #expect(!flag.isSet)
    }

    @Test func mainContextSeesNarrativeStoredByBackfill() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        try seed(context)
        let held = try #require(try records(context).first { $0.activityId == 1 })
        #expect(held.narrativeData == nil)

        _ = try await NarrativeBackfill.run(container: container, narrator: FakeNarrator(), processed: [1], limit: 1)

        let refetched = try #require(try records(context).first { $0.activityId == 1 })
        let stored = try JSONDecoder().decode(WorkoutNarrative.self, from: try #require(refetched.narrativeData))
        #expect(stored.generatedBy == NarrativeConstants.foundationModelsSource)
        #expect(held.narrativeData != nil)
    }

    @Test func hookStoresNothingWhenNarratorFallsBack() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        try seed(context)
        let narrator = FakeNarrator(fallsBack: true)

        let failures = try await NarrativeBackfill.run(container: container, narrator: narrator, processed: [], limit: 10)

        #expect(try records(context).allSatisfy { $0.narrativeData == nil })
        #expect(failures.count == 3)

        let retry = FakeNarrator()
        _ = try await NarrativeBackfill.run(container: container, narrator: retry, processed: [], limit: 10, skipping: failures)
        #expect(await retry.log.count == 0)
    }

    @Test func hookRegeneratesMismatchedKey() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        try seed(context)
        let narrator = FakeNarrator()
        _ = try await NarrativeBackfill.run(container: container, narrator: narrator, processed: [], limit: 10)
        let stale = try #require(try records(context).first { $0.activityId == 2 })
        var narrative = try JSONDecoder().decode(WorkoutNarrative.self, from: try #require(stale.narrativeData))
        narrative.factsKey = "old"
        narrative.findings = narrative.findings.map { _ in "texto velho" }
        stale.narrativeData = F.encoded(narrative)
        try context.save()

        let again = FakeNarrator()
        _ = try await NarrativeBackfill.run(container: container, narrator: again, processed: [], limit: 10)

        let reloaded = try #require(try records(ModelContext(container)).first { $0.activityId == 2 })
        let refreshed = try JSONDecoder().decode(WorkoutNarrative.self, from: try #require(reloaded.narrativeData))
        #expect(await again.log.count == 1)
        #expect(refreshed.factsKey != "old")
        #expect(!refreshed.findings.contains("texto velho"))
    }

    @Test func runsWithNothingToNarrateDoNotSpendAttempts() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        try seed(context)
        for id: Int64 in 10..<15 {
            let empty = F.run(id: id, daysAgo: -Double(id), meters: 2_000 * pow(2, Double(id - 9)))
            empty.localDay = nil
            context.insert(empty)
        }
        try context.save()
        let narrator = FakeNarrator()

        let failures = try await NarrativeBackfill.run(container: container, narrator: narrator, processed: [], limit: 3)

        #expect(failures.isEmpty)
        #expect(await narrator.log.count == 3)
        #expect(try records(context).filter { $0.activityId < 10 }.allSatisfy { $0.narrativeData != nil })
    }
}
