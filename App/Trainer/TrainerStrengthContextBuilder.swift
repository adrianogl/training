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
            keepOriginal: prefs.keptOriginal.contains(day.iso),
            block: StrengthGenerator.block(for: day),
            homeEquipment: prefs.effectiveHomeEquipment
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
        var latestByKey: [String: MFITLoadRecord] = [:]
        for record in records where !record.loads.isEmpty {
            if let current = latestByKey[record.key], current.day >= record.day { continue }
            latestByKey[record.key] = record
        }
        var result: [String: StrengthLoadRecord] = [:]
        for exercise in StrengthCatalog.all {
            let latest = StrengthCatalog.names(of: exercise)
                .compactMap { latestByKey[MFITParser.exerciseKey($0)] }
                .max { $0.day < $1.day }
            guard let latest, let top = latest.loads.max() else { continue }
            result[exercise.id] = StrengthLoadRecord(weight: top, completedAllSets: latest.loads.count >= TrainerStrengthConstants.completedSets, day: latest.day)
        }
        return result
    }
}
