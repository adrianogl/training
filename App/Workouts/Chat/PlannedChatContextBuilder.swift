import Foundation
import WorkoutAnalysis

enum PlannedChatContextBuilder {
    private typealias C = PlannedChatContextConstants

    static func context(title: String, dateText: String, input: BriefingInput, briefing: PlannedBriefing) -> WorkoutChatContext {
        var facts = ["\(title), \(dateText).", briefing.summary]
        facts += briefing.stats.map { "\($0.label): \($0.value)." }
        if !briefing.tags.isEmpty { facts.append(C.tagsPrefix + briefing.tags.map(\.text).joined(separator: ", ") + ".") }
        facts += briefing.reps.map { rep in
            "\(rep.label): " + [rep.pace, rep.heartRate, rep.note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ") + "."
        }
        if let note = briefing.repsNote { facts.append(note) }
        if !briefing.expectations.isEmpty {
            facts.append(C.expectPrefix + briefing.expectations.map { "\($0.label) \($0.value)" }.joined(separator: ", ") + ".")
        }
        if let note = briefing.expectationNote { facts.append(note) }
        facts += briefing.attention.map { C.attentionPrefix + "\($0.title). \($0.detail)" }
        facts += briefing.planB.map { C.planBPrefix + "\($0.title). \($0.detail)" }
        if let race = briefing.raceNote { facts.append(race) }
        if !briefing.bestHours.isEmpty {
            facts.append(C.hoursPrefix + briefing.bestHours.map { "\($0.hour)h \(Int($0.temperature.rounded()))°" }.joined(separator: ", ") + ".")
        }
        if let note = briefing.bestHoursNote { facts.append(note) }
        if let course = briefing.course {
            facts.append(String(format: C.courseFormat, course.name, TodayText.decimal(course.lapKilometers, fractionDigits: 1), course.laps))
        }
        if !briefing.carry.isEmpty { facts.append(C.carryPrefix + briefing.carry.joined(separator: ", ") + ".") }
        return WorkoutChatContext(
            copy: WorkoutChatConstants.plannedCopy,
            title: title,
            facts: facts.joined(separator: "\n"),
            blockLines: briefing.phases.enumerated().map { index, phase in
                "\(index + 1). \(phase.when)" + (phase.length.map { " (\($0))" } ?? "") + ": \(phase.title)" + (phase.detail.isEmpty ? "" : ". \(phase.detail)")
            },
            similarLines: input.similar.map(similarLine),
            dayLine: dayLine(input),
            suggestions: briefing.kind == .intervals
                ? WorkoutChatConstants.suggestionsPlannedIntervals
                : WorkoutChatConstants.suggestionsPlannedContinuous
        )
    }

    private static func similarLine(_ run: SimilarRun) -> String {
        let date = run.day.chartDate.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale))
        var parts = [
            "\(TodayText.decimal(run.kilometers, fractionDigits: 1)) km",
            "pace \(WorkoutFormat.clock(run.paceSecondsPerKm))/km",
        ]
        if let heart = run.averageHeartRate { parts.append("FC média \(Int(heart.rounded())) bpm") }
        if let fade = run.fadeSecondsPerKm, fade > 0 { parts.append(String(format: C.fadeFormat, Int(fade.rounded()))) }
        return "\(date): " + parts.joined(separator: ", ")
    }

    private static func dayLine(_ input: BriefingInput) -> String {
        var parts: [String] = []
        if let readiness = input.readiness { parts.append(String(format: C.readinessFormat, readiness)) }
        var week = String(format: C.weekFormat, TodayText.decimal(input.weekDoneKm, fractionDigits: 1), TodayText.decimal(input.weekPlannedKm, fractionDigits: 1))
        if let goal = input.weekGoalKm { week += String(format: C.goalFormat, TodayText.decimal(goal, fractionDigits: 0)) }
        parts.append(week)
        if let days = input.daysSinceHard { parts.append(String(format: C.hardFormat, days)) }
        if let race = input.race { parts.append(String(format: C.raceFormat, race.name, race.days)) }
        return parts.joined(separator: "; ") + "."
    }
}
