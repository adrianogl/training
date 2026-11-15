import Foundation
import Insights
import TrainingCore
import WorkoutAnalysis

enum TrainerChatContextBuilder {
    private typealias C = TrainerChatConstants

    static func context(plan: TrainerPlan, history: TrainerHistory, today: Day) -> WorkoutChatContext {
        let upcoming = plan.workouts
            .filter { $0.day >= today && $0.day < today.adding(days: C.upcomingDays) }
            .sorted { $0.day < $1.day }
        var facts = [goalLine(plan, today: today), weekLine(plan, today: today), pacesLine(plan.paces)]
        if let summary = TrainerEngine.goalPaceSummary(target: plan.target, paces: plan.paces) { facts.append(summary) }
        if !plan.strength.isEmpty { facts.append(C.strengthPrefix + TrainerText.strengthSummary(plan.strength) + ".") }
        facts.append(longLine(plan))
        facts.append(C.upcomingHeader)
        facts += upcoming.map(dayLine)
        facts.append(C.rules)
        return WorkoutChatContext(
            copy: C.copy,
            title: C.title,
            facts: facts.joined(separator: "\n"),
            blockLines: upcoming.map { "\(TrainerText.dayMonth($0.day)): \(C.rationalePrefix)\($0.rationale)" },
            similarLines: recentRuns(history, today: today),
            dayLine: changesLine(plan),
            suggestions: C.suggestions
        )
    }

    private static func goalLine(_ plan: TrainerPlan, today: Day) -> String {
        var line = String(format: C.goalFormat, TrainerText.targetTitle(plan.target))
        if let distance = plan.target.distanceMeters { line += ", \(TrainerText.distance(distance))" }
        if let seconds = plan.target.goalSeconds { line += String(format: C.goalTimeFormat, WorkoutFormat.clock(seconds)) }
        if let date = plan.target.date, today.days(until: date) > 0 { line += String(format: C.countdownFormat, today.days(until: date)) }
        return line + "."
    }

    private static func weekLine(_ plan: TrainerPlan, today: Day) -> String {
        guard let week = plan.weeks.first(where: { $0.start <= today && today < $0.start.adding(days: TrainerConstants.weekdayCount) }) else { return C.noWeek }
        let phase = TrainerText.phases.first { $0.0 == week.phase }?.1 ?? ""
        return String(
            format: C.weekFormat, week.index, plan.weeks.count, phase,
            TrainerText.kilometersNumber(week.plannedMeters), TrainerText.kilometersNumber(week.longMeters)
        ) + (week.isRecovery ? C.recoverySuffix : "") + "."
    }

    private static func pacesLine(_ paces: TrainerPaces) -> String {
        func source(_ value: TrainerPaceSource?) -> String {
            value.flatMap { C.sourceNames[$0] }.map { String(format: C.sourceFormat, $0) } ?? ""
        }
        return String(
            format: C.pacesFormat,
            TrainerText.pace(paces.easy), TrainerText.pace(paces.long),
            TrainerText.pace(paces.threshold), source(paces.thresholdSource),
            TrainerText.pace(paces.vo2max), source(paces.vo2Source)
        )
    }

    private static func longLine(_ plan: TrainerPlan) -> String {
        guard plan.longMode == .blocks else { return C.longModeContinuous }
        return C.longModeBlocks + TrainerText.longStageCaption(stage: plan.longStage, streak: plan.longStageStreak) + "."
    }

    private static func dayLine(_ workout: TrainerWorkout) -> String {
        var parts = ["\(TrainerText.weekdayShort(workout.day)) \(TrainerText.dayMonth(workout.day)): \(workout.title)"]
        guard workout.kind != .off else { return parts[0] + "." }
        parts.append(TrainerText.distance(workout.totalMeters))
        if let range = TrainerText.paceRange(low: workout.paceLow, high: workout.paceHigh) { parts.append(range) }
        if let method = workout.method { parts.append(C.methodPrefix + method.title + String(format: C.sourceFormat, method.source)) }
        let rows = TrainerText.stepRows(workout).map { $0.detail.isEmpty ? $0.title : "\($0.title) \($0.detail)" }
        if !rows.isEmpty { parts.append(C.structurePrefix + rows.joined(separator: ", ")) }
        return parts.joined(separator: ", ") + (workout.edited ? C.editedSuffix : "") + "."
    }

    private static func recentRuns(_ history: TrainerHistory, today: Day) -> [String] {
        let runs = history.runs.filter { $0.day <= today && $0.meters > 0 }.sorted { $0.day > $1.day }.prefix(C.recentRuns)
        guard !runs.isEmpty else { return [C.runsEmpty] }
        return runs.map { run in
            var parts = [TrainerText.distance(run.meters), C.runKindName(run.kind), TrainerText.pace(run.seconds / (run.meters / 1_000))]
            if let heartRate = run.averageHeartRate { parts.append(String(format: C.heartRateFormat, Int(heartRate.rounded()))) }
            if let onTarget = run.activeOnTarget, let total = run.activeTotal { parts.append(String(format: C.onTargetFormat, onTarget, total)) }
            return "\(TrainerText.dayMonth(run.day)): " + parts.joined(separator: ", ") + "."
        }
    }

    private static func changesLine(_ plan: TrainerPlan) -> String? {
        let versions = plan.versions.suffix(C.recentVersions).reversed()
        guard !versions.isEmpty else { return nil }
        return versions.map { String(format: C.versionFormat, $0.number, TrainerText.triggerText($0.trigger), $0.summary) }.joined(separator: " ")
    }
}
