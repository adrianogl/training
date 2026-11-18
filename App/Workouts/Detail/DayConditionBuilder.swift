import Foundation
import Insights
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

enum DayConditionBuilder {
    nonisolated static func legDays(store: StrengthProgramStore = StrengthProgramStore()) -> Set<Day> {
        let known = store.load().known
        return Set(known.flatMap { workout -> [Day] in
            let entries = workout.blocks.flatMap { block in block.exercises.map { (category: $0.category, sets: block.sets) } }
            guard StrengthMuscles.isLegDay(entries) else { return [] }
            return workout.completions.compactMap { Day(iso: $0.day) }
        })
    }

    nonisolated static func dailyByDay(_ context: ModelContext) -> [String: DailyRecord] {
        let records = (try? context.fetch(FetchDescriptor<DailyRecord>())) ?? []
        return Dictionary(records.map { ($0.day, $0) }) { first, _ in first }
    }

    static func condition(record: ActivityRecord, records: [ActivityRecord], daily: DailyRecord?, legDays: Set<Day>) -> DayCondition {
        let day = WorkoutAnalysisContext.day(record)
        return DayCondition(
            sleepSeconds: daily?.sleepSeconds,
            sleepScore: daily?.sleepScore,
            hrvBelowBalanced: daily.flatMap { daily in daily.hrvLastNight.flatMap { value in daily.hrvBalancedLow.map { value < $0 } } } ?? false,
            bodyBattery: daily?.bodyBatteryMorningMax,
            previousDay: previousDay(day.adding(days: -1), records: records, legDays: legDays)
        )
    }

    private static func previousDay(_ day: Day, records: [ActivityRecord], legDays: Set<Day>) -> PreviousDayLoad? {
        let runs = records.filter { ActivityTypeKey.isRun($0.typeKey) && WorkoutAnalysisContext.day($0) == day }
        let kinds = Set(runs.map { classifyRun($0, longGoalKm: nil, raceGoalKms: []) })
        if kinds.contains(.intervals) { return .intervals }
        if kinds.contains(.tempo) { return .threshold }
        if kinds.contains(.long) { return .long }
        return legDays.contains(day) ? .legs : nil
    }
}
