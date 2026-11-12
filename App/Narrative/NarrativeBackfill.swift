import Foundation
import Narrative
import Storage
import SwiftData
import TrainingCore

enum NarrativeBackfill {
    static func run(
        container: ModelContainer,
        narrator: any Narrator,
        processed: Set<Int64>,
        limit: Int,
        skipping: Set<String> = [],
        onStep: (@Sendable () -> Void)? = nil
    ) async throws -> Set<String> {
        let task = Task.detached(priority: .utility) {
            try await backfill(container: container, narrator: narrator, processed: processed, limit: limit, skipping: skipping, onStep: onStep)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func backfill(
        container: ModelContainer,
        narrator: any Narrator,
        processed: Set<Int64>,
        limit: Int,
        skipping: Set<String>,
        onStep: (@Sendable () -> Void)?
    ) async throws -> Set<String> {
        guard !(narrator is TemplateNarrator) else { return [] }
        onStep?()
        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        let runs = records.filter { $0.hasStart && ActivityTypeKey.isRun($0.typeKey) }
        let ordered = runs.filter { processed.contains($0.activityId) } + runs.filter { !processed.contains($0.activityId) }
        let inputs = WorkoutAnalysisContext.inputs(records: records, in: context)
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        var attempts = 0
        var checked = 0
        var failures: Set<String> = []
        for record in ordered where attempts < limit {
            try Task.checkCancellation()
            onStep?()
            let stored = record.narrativeData.flatMap { try? decoder.decode(WorkoutNarrative.self, from: $0) }
            let isFresh = processed.contains(record.activityId)
            if stored != nil, !isFresh {
                guard checked < AppConstants.narrativeScanLimit else { continue }
                checked += 1
            }
            let analysis = WorkoutAnalysisContext.build(record: record, records: records, inputs: inputs)
            guard !analysis.assessment.orderedFindings.isEmpty || analysis.evolution != nil else { continue }
            let key = NarrativeFacts.key(analysis.assessment, blocks: analysis.blocks, evolution: analysis.evolution)
            let attempt = "\(record.activityId):\(key)"
            guard stored?.factsKey != key, !skipping.contains(attempt) else { continue }
            attempts += 1
            let narrative = await narrator.narrate(analysis.assessment, blocks: analysis.blocks, evolution: analysis.evolution)
            guard narrative.generatedBy == NarrativeConstants.foundationModelsSource, narrative.factsKey == key else {
                failures.insert(attempt)
                continue
            }
            record.narrativeData = try encoder.encode(narrative)
            try context.save()
        }
        return failures
    }
}
