import Foundation
import Insights
import Metrics
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

enum TrainerHistoryLoader {
    private typealias C = TrainerConstants

    nonisolated static func load(container: ModelContainer, today: Day) -> TrainerHistory {
        let context = ModelContext(container)
        let runs = fetchRuns(context: context, today: today)
        let raceKms = ((try? context.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.deletedAt == nil }))) ?? [])
            .map { $0.distance / 1_000 }
        let inputs = WorkoutAnalysisContext.inputs(records: runs, in: context)
        let deepFrom = today.adding(days: -C.deepAnalysisDays)
        let trainerRuns = runs.map { record in
            trainerRun(record, runs: runs, raceKms: raceKms, inputs: inputs, deep: runDay(record) >= deepFrom)
        }
        return TrainerHistory(
            runs: trainerRuns,
            readiness: readiness(context: context, today: today),
            predictions: predictions(context: context, today: today),
            strength: fetchStrength(context: context, today: today)
        )
    }

    private nonisolated static func fetchRuns(context: ModelContext, today: Day) -> [ActivityRecord] {
        let lower = date(of: today.adding(days: -C.historyDays))
        let upper = date(of: today.adding(days: 1))
        var descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= lower && $0.start < upper })
        descriptor.sortBy = [SortDescriptor(\.start)]
        return ((try? context.fetch(descriptor)) ?? []).filter { $0.hasStart && ActivityTypeKey.isRun($0.typeKey) }
    }

    private nonisolated static func fetchStrength(context: ModelContext, today: Day) -> [TrainerStrengthDone] {
        let lower = date(of: today.adding(days: -C.historyDays))
        let upper = date(of: today.adding(days: 1))
        var descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= lower && $0.start < upper })
        descriptor.sortBy = [SortDescriptor(\.start)]
        return ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.hasStart && ActivityTypeKey.isStrength($0.typeKey) }
            .map { TrainerStrengthDone(activityId: $0.activityId, day: runDay($0), name: $0.name, seconds: $0.duration ?? 0) }
    }

    private nonisolated static func trainerRun(
        _ record: ActivityRecord,
        runs: [ActivityRecord],
        raceKms: [Double],
        inputs: WorkoutAnalysisInputs,
        deep: Bool
    ) -> TrainerRun {
        var fadeKm: Int?
        var pauses: Int?
        var onTarget: Int?
        var total: Int?
        if deep {
            if let analysis = detailedAnalysis(record: record, history: runs, daily: [], longGoalKm: nil, raceGoalKms: raceKms) {
                fadeKm = analysis.fadeKm
                pauses = analysis.pauseKilometers.count
            }
            let analysis = WorkoutAnalysisContext.build(record: record, records: runs, inputs: inputs)
            let active = analysis.blocks.filter { $0.kind == .active }
            if analysis.hasPrescription, !active.isEmpty {
                total = active.count
                onTarget = active.filter { $0.status == .inTarget || $0.status == .faster }.count
            }
        }
        return TrainerRun(
            activityId: record.activityId,
            day: runDay(record),
            meters: record.distance ?? 0,
            seconds: record.movingDuration ?? record.duration ?? 0,
            kind: classifyRun(record, longGoalKm: nil, raceGoalKms: raceKms),
            averageHeartRate: record.averageHR,
            fadeKm: fadeKm,
            pauses: pauses,
            activeOnTarget: onTarget,
            activeTotal: total
        )
    }

    private nonisolated static func readiness(context: ModelContext, today: Day) -> [Day: Int] {
        let lower = today.adding(days: -C.historyDays).iso
        let descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.readinessScore != nil && $0.day >= lower })
        return ((try? context.fetch(descriptor)) ?? []).reduce(into: [:]) { result, record in
            if let score = record.readinessScore, let day = Day(iso: record.day) { result[day] = score }
        }
    }

    private nonisolated static func predictions(context: ModelContext, today: Day) -> [Double: Double] {
        guard let efforts = try? raceEfforts(context: context, today: today) else { return [:] }
        return C.predictionDistances.reduce(into: [:]) { result, distance in
            if let seconds = predict(distance: distance, efforts: efforts, on: today) { result[distance] = seconds }
        }
    }

    private nonisolated static func runDay(_ record: ActivityRecord) -> Day {
        record.localDay.flatMap(Day.init(iso:)) ?? Day.today(now: record.start)
    }

    private nonisolated static func date(of day: Day) -> Date {
        Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .distantPast
    }
}
