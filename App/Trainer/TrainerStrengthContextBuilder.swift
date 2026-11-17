import Foundation
import GarminAPI
import Insights
import MFIT
import TrainingCore

enum TrainerStrengthContextBuilder {
    static func context(
        day: Day, plan: TrainerPlan?, externalKind: TrainerDayKind? = nil, readiness: Int?, prefs: TrainerStrengthPrefs,
        cache: StrengthProgramCache, schedule: StrengthSchedule
    ) -> StrengthContext {
        let week = plan?.weeks.first { $0.start == day.weekStart }
        let raceDays: Int? = plan.flatMap { plan in plan.target.kind == .race ? plan.target.date.map { day.days(until: $0) } : nil }
        return StrengthContext(
            runKind: plan?.workouts.first { $0.day == day }?.kind ?? externalKind,
            isRecoveryWeek: week?.isRecovery ?? false,
            daysToRace: raceDays,
            readiness: readiness,
            pain: prefs.pain,
            coveredPatterns: covered(program: cache.program, schedule: schedule, week: day.weekStart),
            loads: loads(cache.loads),
            swaps: prefs.swaps[day.iso] ?? [:],
            keepOriginal: prefs.keptOriginal.contains(day.iso)
        )
    }

    static func covered(program: MFITProgram?, schedule: StrengthSchedule, week: Day) -> Set<MovementPattern> {
        let workouts = schedule.workouts(program, from: week, through: week.adding(days: TrainerConstants.weekdayCount - 1))
        let categories = workouts.flatMap { $0.blocks.flatMap { $0.exercises.compactMap(\.category) } }
        return Set(categories.compactMap(StrengthCatalog.pattern(garminCategory:)))
    }

    static func coveredByWeekday(program: MFITProgram?, schedule: StrengthSchedule, week: Day) -> [Int: [MovementPattern]] {
        let workouts = schedule.workouts(program, from: week, through: week.adding(days: TrainerConstants.weekdayCount - 1))
        var result: [Int: [MovementPattern]] = [:]
        for workout in workouts {
            guard let day = Day(iso: workout.day) else { continue }
            let patterns = Set(workout.blocks.flatMap { $0.exercises.compactMap(\.category) }.compactMap(StrengthCatalog.pattern(garminCategory:)))
            result[day.weekStart.days(until: day) + 1, default: []].append(contentsOf: patterns)
        }
        return result.mapValues { Array(Set($0)).sorted { $0.rawValue < $1.rawValue } }
    }

    static func loads(_ records: [MFITLoadRecord]) -> [String: StrengthLoadRecord] {
        var result: [String: StrengthLoadRecord] = [:]
        for exercise in StrengthCatalog.all {
            let key = MFITParser.exerciseKey(exercise.name)
            guard let latest = records.filter({ $0.key == key && !$0.loads.isEmpty }).max(by: { $0.day < $1.day }),
                  let top = latest.loads.max() else { continue }
            result[exercise.id] = StrengthLoadRecord(weight: top, completedAllSets: latest.loads.count >= TrainerStrengthConstants.completedSets)
        }
        return result
    }
}
