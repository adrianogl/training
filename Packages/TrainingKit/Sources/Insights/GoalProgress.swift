import FITReader
import Metrics
import Foundation
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

private typealias C = GoalProgressConstants

public func activeGoals(in context: ModelContext) throws -> [GoalRecord] {
    try context.fetch(FetchDescriptor<GoalRecord>(sortBy: [SortDescriptor(\.createdAt)]))
        .filter { $0.deletedAt == nil && !$0.archived && $0.goalKind != nil }
}

public func goalSnapshots(context: ModelContext, today: Day, calendar: Calendar = .current) throws -> [GoalSnapshot] {
    let goals = try activeGoals(in: context)
    guard !goals.isEmpty else { return [] }
    let runs = try context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        .filter { ActivityTypeKey.isRun($0.typeKey) && $0.localDay != nil }
    let efforts = goals.contains { $0.goalKind == .time } ? try raceEfforts(context: context, today: today) : []
    return goals.compactMap { goal -> GoalSnapshot? in
        guard let kind = goal.goalKind else { return nil }
        let created = Day.today(in: calendar.timeZone, now: goal.createdAt)
        let progress: GoalProgress = switch kind {
        case .time: .time(timeGoalProgress(goal, efforts: efforts, runs: runs, createdOn: created, today: today))
        case .continuousLong: .continuousLong(longGoalProgress(goal, runs: longGoalCandidates(goal, runs: runs), createdOn: created))
        }
        return GoalSnapshot(
            id: goal.id, kind: kind, distanceKm: goal.distanceKm, targetSeconds: goal.targetSeconds,
            deadline: goal.deadline.flatMap(Day.init(iso:)), paceSecondsPerKm: goal.paceSecondsPerKm, progress: progress
        )
    }
}

public func timeGoalProgress(_ goal: GoalRecord, efforts: [Effort], runs: [ActivityRecord], createdOn: Day, today: Day) -> TimeGoalProgress {
    let target = goal.targetSeconds ?? 0
    let meters = goal.distanceKm * C.metersPerKilometer
    let outlook = raceOutlook(distance: meters, raceDay: goal.deadline.flatMap(Day.init(iso:)), goalSeconds: target, efforts: efforts, today: today)
    let achieved = runs.compactMap { run -> Day? in
        guard let day = run.localDay.flatMap(Day.init(iso:)), day >= createdOn,
              let distance = run.distance, distance >= meters * C.timeMatchLow, distance <= meters * C.timeMatchHigh,
              let seconds = run.duration, seconds * (meters / distance) <= target else { return nil }
        return day
    }.min()
    return TimeGoalProgress(
        todaySeconds: outlook.today,
        gapSeconds: outlook.today.map { $0 - target },
        crossing: outlook.goalCrossing,
        achievedOn: achieved
    )
}

public func longGoalCandidates(_ goal: GoalRecord, runs: [ActivityRecord]) -> [ActivityRecord] {
    let minimum = goal.distanceKm * C.metersPerKilometer * C.longShare
    return Array(runs.filter { ($0.distance ?? 0) >= minimum }.sorted { $0.start > $1.start }.prefix(C.longRuns))
}

public func longGoalProgress(_ goal: GoalRecord, runs: [ActivityRecord], createdOn: Day) -> LongGoalProgress {
    let pace = goal.paceSecondsPerKm ?? 0
    let checks = runs.compactMap { run -> LongRunCheck? in
        guard let day = run.localDay.flatMap(Day.init(iso:)) else { return nil }
        let samples = run.samplesData.flatMap { try? JSONDecoder().decode([FITSample].self, from: $0) } ?? []
        guard let continuity = runContinuity(samples) else {
            return LongRunCheck(activityId: run.activityId, day: day, distanceKm: (run.distance ?? 0) / C.metersPerKilometer)
        }
        return LongRunCheck(
            activityId: run.activityId,
            day: day,
            distanceKm: continuity.totalMeters / C.metersPerKilometer,
            longestContinuousKm: continuity.longestContinuousMeters / C.metersPerKilometer,
            pauses: continuity.pauses,
            paceSecondsPerKm: continuity.paceSecondsPerKm,
            met: continuity.meetsContinuousGoal(distanceKm: goal.distanceKm, paceSecondsPerKm: pace)
        )
    }.sorted { $0.day < $1.day }
    let known = checks.compactMap(\.longestContinuousKm)
    return LongGoalProgress(
        runs: checks,
        metCount: checks.filter { $0.met == true }.count,
        bestContinuousKm: known.max(),
        achievedOn: checks.filter { $0.met == true && $0.day >= createdOn }.map(\.day).min()
    )
}
