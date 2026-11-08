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

private struct FakeNarrator: Narrator {
    let log = CallLog()

    func narrate(_ assessment: WorkoutAssessment, blocks: [WorkoutBlock], evolution: EvolutionFacts?) async -> WorkoutNarrative {
        await log.record()
        return WorkoutNarrative(
            findings: assessment.orderedFindings.map { "fake \($0.kind.rawValue)" },
            evolution: evolution.map { _ in "fake evolution" },
            generatedBy: "fake"
        )
    }
}

@MainActor
@Suite struct NarrativeBackfillTests {
    private typealias F = WorkoutDetailFixtures

    @Test func postSyncHookStoresNarrative() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let name = "Tiros 3 x 1 km"
        context.insert(F.run(id: 1, meters: 5_900, workoutName: name, structure: F.intervalStructure(tiroSeconds: 245)))
        context.insert(F.run(id: 2, daysAgo: 7, meters: 5_900, workoutName: name, structure: F.intervalStructure(tiroSeconds: 250)))
        context.insert(F.run(id: 3, daysAgo: 14, meters: 5_900, workoutName: name, structure: F.intervalStructure()))
        try context.save()
        let narrator = FakeNarrator()

        try await NarrativeBackfill.run(context: context, narrator: narrator, processed: [3], limit: 1)

        let records = try context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        let byId = Dictionary(uniqueKeysWithValues: records.map { ($0.activityId, $0) })
        for id: Int64 in [1, 3] {
            let record = try #require(byId[id])
            let narrative = try JSONDecoder().decode(WorkoutNarrative.self, from: try #require(record.narrativeData))
            let analysis = WorkoutAnalysisContext.build(record: record, records: records, in: context)
            #expect(!analysis.assessment.orderedFindings.isEmpty)
            #expect(narrative.findings.count == analysis.assessment.orderedFindings.count)
            #expect(narrative.generatedBy == "fake")
        }
        let first = try JSONDecoder().decode(WorkoutNarrative.self, from: try #require(byId[1]?.narrativeData))
        #expect(first.evolution == "fake evolution")
        #expect(byId[2]?.narrativeData == nil)
        #expect(await narrator.log.count == 2)
    }
}
