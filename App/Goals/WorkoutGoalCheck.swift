import FITReader
import Foundation
import Insights
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

enum WorkoutGoalCheck {
    private typealias C = WorkoutGoalConstants

    static func entries(activityId: Int64, blocks: [WorkoutBlock], context: ModelContext) -> [WorkoutGoalEntry] {
        let goals = ((try? context.fetch(FetchDescriptor<GoalRecord>())) ?? []).filter { $0.deletedAt == nil && !$0.archived }
        guard !goals.isEmpty else { return [] }
        let runs = ((try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? [])
            .filter { ActivityTypeKey.isRun($0.typeKey) }
        guard let record = runs.first(where: { $0.activityId == activityId }) else { return [] }
        return entries(record: record, runs: runs, blocks: blocks, goals: goals)
    }

    static func entries(record: ActivityRecord, runs: [ActivityRecord], blocks: [WorkoutBlock], goals: [GoalRecord]) -> [WorkoutGoalEntry] {
        let kind = classifyRun(
            record,
            longGoalKm: goals.filter { $0.goalKind == .continuousLong }.map(\.distanceKm).min(),
            raceGoalKms: goals.filter { $0.goalKind == .time }.map(\.distanceKm)
        )
        return goals.compactMap { goal in
            switch goal.goalKind {
            case .continuousLong: kind == .long ? longEntry(record: record, runs: runs, goal: goal) : nil
            case .time: timeEntry(kind: kind, record: record, blocks: blocks, goal: goal)
            case nil: nil
            }
        }
    }

    static func samples(_ record: ActivityRecord) -> [FITSample] {
        record.samplesData.flatMap { try? JSONDecoder().decode([FITSample].self, from: $0) } ?? []
    }

    private static func longEntry(record: ActivityRecord, runs: [ActivityRecord], goal: GoalRecord) -> WorkoutGoalEntry? {
        let title = GoalsText.title(goal)
        guard let continuity = runContinuity(samples(record)) else {
            return WorkoutGoalEntry(id: goal.id.uuidString, title: title, status: C.notYet, good: false, lines: [C.noFit])
        }
        let target = goal.paceSecondsPerKm ?? 0
        let met = continuity.meetsContinuousGoal(distanceKm: goal.distanceKm, paceSecondsPerKm: target)
        var lines = continuity.pauses.map { String(format: C.pauseLineFormat, Int($0.seconds.rounded()), km($0.startMeters / 1_000)) }
        let longest = continuity.longestContinuousMeters / 1_000
        if continuity.pauses.isEmpty {
            lines.append(String(format: C.fullDistanceFormat, km(continuity.totalMeters / 1_000)))
        } else if let previous = previousLongest(before: record, runs: runs, goal: goal) {
            lines.append(String(format: C.longestComparedFormat, km(longest), km(previous)))
        } else {
            lines.append(String(format: C.longestFormat, km(longest)))
        }
        let missing = goal.distanceKm - continuity.totalMeters / 1_000
        if missing > 0.05 { lines.append(String(format: C.shortFormat, km(missing))) }
        if let pace = continuity.paceSecondsPerKm {
            let over = Int((pace - target).rounded())
            lines.append(over <= 0
                ? String(format: C.paceOkFormat, WorkoutFormat.clock(pace), WorkoutFormat.clock(target))
                : String(format: C.paceSlowFormat, WorkoutFormat.clock(pace), over, WorkoutFormat.clock(target)))
        }
        let status = met ? C.met : continuity.pauses.isEmpty ? C.almost : continuity.pauses.count == 1 ? C.pausesOne : String(format: C.pausesFormat, continuity.pauses.count)
        return WorkoutGoalEntry(id: goal.id.uuidString, title: title, status: status, good: met, lines: lines)
    }

    private static func previousLongest(before record: ActivityRecord, runs: [ActivityRecord], goal: GoalRecord) -> Double? {
        runs.first { $0.start < record.start && isLongRun(name: $0.workoutName ?? $0.name, distanceMeters: $0.distance ?? 0, goalKm: goal.distanceKm) && runContinuity(samples($0)) != nil }
            .flatMap { runContinuity(samples($0)) }
            .map { $0.longestContinuousMeters / 1_000 }
    }

    private static func timeEntry(kind: RunKind, record: ActivityRecord, blocks: [WorkoutBlock], goal: GoalRecord) -> WorkoutGoalEntry? {
        guard let target = goal.targetSeconds, goal.distanceKm > 0 else { return nil }
        let meters = goal.distanceKm * 1_000
        let goalPace = target / goal.distanceKm
        let title = GoalsText.title(goal)
        if kind == .race, let distance = record.distance, let seconds = record.duration, distance >= meters * C.timeMatchLow, distance <= meters * C.timeMatchHigh {
            let projected = seconds * meters / distance
            let beaten = projected <= target
            let verdict = beaten ? C.raceBeaten : String(format: C.raceMissFormat, WorkoutFormat.clock(projected - target))
            return WorkoutGoalEntry(
                id: goal.id.uuidString, title: title, status: beaten ? C.met : C.notYet, good: beaten,
                lines: [String(format: C.raceTimeFormat, GoalsText.distanceLabel(goal.distanceKm), WorkoutFormat.clock(projected), verdict)]
            )
        }
        guard kind == .intervals || kind == .tempo, C.paceGoalDistances.contains(goal.distanceKm) else { return nil }
        let active = blocks.filter { $0.kind == .active }
        let activeMeters = active.map(\.distance).reduce(0, +)
        let activeSeconds = active.map(\.seconds).reduce(0, +)
        guard activeMeters > 0, activeSeconds > 0 else { return nil }
        let pace = activeSeconds / (activeMeters / 1_000)
        let delta = Int((pace - goalPace).rounded())
        let line: String
        if abs(Double(delta)) < C.paceTolerance {
            line = String(format: C.blocksEqualFormat, WorkoutFormat.clock(pace))
        } else if delta < 0 {
            line = String(format: C.blocksFasterFormat, WorkoutFormat.clock(pace), -delta, WorkoutFormat.clock(goalPace))
        } else {
            line = String(format: C.blocksSlowerFormat, WorkoutFormat.clock(pace), delta, WorkoutFormat.clock(goalPace))
        }
        return WorkoutGoalEntry(id: goal.id.uuidString, title: title, status: C.paceStatus, good: delta <= 0, lines: [line, C.blocksNote])
    }

    private static func km(_ value: Double) -> String {
        TodayText.decimal(value, fractionDigits: 1)
    }
}
