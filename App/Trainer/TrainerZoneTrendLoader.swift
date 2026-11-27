import Foundation
import Insights
import Storage
import Sync
import SwiftData
import TrainingCore
import WorkoutAnalysis

enum TrainerZoneTrendLoader {
    nonisolated static func load(
        container: ModelContainer, today: Day, target: TrainerTarget?, overrides: [TrainerPaceKind: Double]
    ) -> TrainerZoneTrend {
        let context = ModelContext(container)
        let history = TrainerHistoryLoader.load(container: container, today: today, since: TrainerZoneTrends.historyStart(today: today))
        let first = TrainerZoneTrends.weekStarts(today: today).first ?? today
        let byId = Dictionary(history.runs.map { ($0.activityId, $0) }, uniquingKeysWith: { lhs, _ in lhs })
        let records = fetchRuns(context: context, from: first, today: today)
        let inputs = WorkoutAnalysisContext.inputs(records: records, in: context)
        let runs = records.compactMap { record -> TrainerZoneTrendRun? in
            guard let run = byId[record.activityId], run.day >= first else { return nil }
            let analysis = WorkoutAnalysisStore.stored(record) ?? WorkoutAnalysisContext.build(record: record, records: records, inputs: inputs)
            guard !analysis.blocks.isEmpty else { return nil }
            return TrainerZoneTrendRun(day: run.day, kind: run.kind, blocks: analysis.blocks, samples: SampleStore.samples(record))
        }
        let days = (0...first.days(until: today)).map { first.adding(days: $0) }
        return TrainerZoneTrends.build(
            history: history, runs: runs, target: target, overrides: overrides,
            thresholdHeartRates: (try? thresholdHeartRates(on: days, in: context)) ?? [:],
            maxHeartRate: (try? runningZonesRecord(in: context))?.maxHeartRate, today: today
        )
    }

    private nonisolated static func fetchRuns(context: ModelContext, from first: Day, today: Day) -> [ActivityRecord] {
        let lower = date(of: first)
        let upper = date(of: today.adding(days: 1))
        var descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= lower && $0.start < upper })
        descriptor.sortBy = [SortDescriptor(\.start)]
        return ((try? context.fetch(descriptor)) ?? []).filter { $0.hasStart && ActivityTypeKey.isRun($0.typeKey) }
    }

    private nonisolated static func date(of day: Day) -> Date {
        Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .distantPast
    }
}
