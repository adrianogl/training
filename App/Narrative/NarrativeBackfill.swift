import Foundation
import Narrative
import Storage
import SwiftData
import TrainingCore

@MainActor enum NarrativeBackfill {
    static func run(context: ModelContext, narrator: any Narrator, processed: Set<Int64>, limit: Int) async throws {
        let records = try context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        let runs = records.filter { $0.hasStart && ActivityTypeKey.isRun($0.typeKey) }
        let fresh = runs.filter { processed.contains($0.activityId) }
        let missing = runs.filter { $0.narrativeData == nil && !processed.contains($0.activityId) }.prefix(limit)
        let encoder = JSONEncoder()
        for record in fresh + missing {
            try Task.checkCancellation()
            let analysis = WorkoutAnalysisContext.build(record: record, records: records, in: context)
            let narrative = await narrator.narrate(analysis.assessment, blocks: analysis.blocks, evolution: analysis.evolution)
            record.narrativeData = try encoder.encode(narrative)
            try context.save()
        }
    }
}
