import Foundation
import Storage
import SwiftData

enum WorkoutAnalysisStore {
    static func encode(_ analysis: WorkoutAnalysisContext) -> Data? {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try? encoder.encode(analysis)
    }

    static func stored(_ record: ActivityRecord) -> WorkoutAnalysisContext? {
        guard let key = record.scoreKey, key.hasPrefix(ScoreStore.versionTag + WorkoutConstants.scoreKeySeparator),
              let data = record.analysisData else { return nil }
        return try? PropertyListDecoder().decode(WorkoutAnalysisContext.self, from: data)
    }

    static func load(activityId: Int64, container: ModelContainer) async -> WorkoutAnalysisContext? {
        await Task.detached(priority: .userInitiated) {
            PerformanceTrace.measure("análise do treino") {
                let context = ModelContext(container)
                var descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == activityId })
                descriptor.fetchLimit = 1
                guard let record = try? context.fetch(descriptor).first else { return nil }
                if let stored = stored(record) { return stored }
                let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
                return WorkoutAnalysisContext.build(record: record, records: records, in: context)
            }
        }.value
    }
}
