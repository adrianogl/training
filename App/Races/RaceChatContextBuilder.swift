import Foundation
import Metrics
import TrainingCore
import WorkoutAnalysis

enum RaceChatContextBuilder {
    private typealias C = RaceChatContextConstants

    static func key(_ id: UUID) -> Int64 {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0.prefix(8)) }
        return bytes.reduce(Int64(0)) { ($0 << 8) | Int64($1) }
    }

    static func next(info: RaceInfo, today: Day, outlook: RaceOutlookFacts, checklist: [ChecklistItem], blockReading: String, strategy: [KmPlan], block: [BlockWeek], taper: TaperPlan?, targetText: String?) -> WorkoutChatContext {
        var facts = [header(info), String(format: C.countdownFormat, max(today.days(until: info.day), 0))]
        if let goal = info.goalSeconds {
            facts.append(String(format: C.goalFormat, WorkoutFormat.clock(goal), RacesText.goalPaceText(goalSeconds: goal, distance: info.distance)))
        } else {
            facts.append(C.noGoal)
        }
        if let today = outlook.today { facts.append(String(format: C.todayFormat, WorkoutFormat.clock(today))) }
        if let raceDay = outlook.raceDay { facts.append(String(format: C.raceDayFormat, WorkoutFormat.clock(raceDay))) }
        if let sentence = outlook.sentence { facts.append(sentence) }
        if let targetText { facts.append(targetText + ".") }
        facts += checklist.map { "\($0.title): \($0.detail) (\(C.statuses[$0.status] ?? ""))." }
        if !blockReading.isEmpty { facts.append(blockReading) }
        if let taper { facts.append(taper.advice) }
        return WorkoutChatContext(
            copy: WorkoutChatConstants.nextRaceCopy,
            title: info.name,
            facts: facts.joined(separator: "\n"),
            blockLines: strategy.map { "km \($0.index + 1): pace \(WorkoutFormat.clock($0.pace))/km" + ($0.manual ? C.manualSuffix : "") },
            similarLines: block.map { week in
                String(format: C.weekFormat, week.start.day, week.start.month, TodayText.decimal(week.km, fractionDigits: 1)) + (week.projected ? C.projectedSuffix : "")
            },
            dayLine: taper.map(taperLine),
            suggestions: WorkoutChatConstants.suggestionsNextRace
        )
    }

    static func completed(_ summary: CompletedRaceSummary) -> WorkoutChatContext {
        var facts = [header(summary.info)]
        if let result = summary.resultSeconds { facts.append(String(format: C.resultFormat, WorkoutFormat.clock(result))) }
        if let goal = summary.goalSeconds { facts.append(String(format: C.goalOnlyFormat, WorkoutFormat.clock(goal))) }
        if let delta = summary.resultVsGoalText { facts.append(String(format: C.vsGoalFormat, delta)) }
        if let eve = summary.eveSeconds { facts.append(String(format: C.eveFormat, WorkoutFormat.clock(eve))) }
        if let delta = summary.resultVsEveText { facts.append(String(format: C.vsEveFormat, delta)) }
        if summary.isPR { facts.append(C.personalRecord) }
        let lesson = summary.lesson
        let lessonLines = lesson.negative.map { lessonLine(C.adjustPrefix, $0) }
            + lesson.positive.map { lessonLine(C.wentWellPrefix, $0) }
            + lesson.expected.map { lessonLine(C.nextPrefix, $0) }
        let dayParts = [
            summary.eveSeconds.map { String(format: C.eveFormat, WorkoutFormat.clock($0)) },
            summary.goalSeconds.map { String(format: C.goalOnlyFormat, WorkoutFormat.clock($0)) },
        ].compactMap { $0 }
        return WorkoutChatContext(
            copy: WorkoutChatConstants.completedRaceCopy,
            title: summary.info.name,
            facts: facts.joined(separator: "\n"),
            blockLines: summary.splits.map { split in
                "km \(split.index + 1): pace \(WorkoutFormat.clock(split.pace))/km" + (split.planned.map { String(format: C.plannedSuffix, WorkoutFormat.clock($0)) } ?? "")
            },
            similarLines: lessonLines,
            dayLine: dayParts.isEmpty ? nil : dayParts.joined(separator: " "),
            suggestions: WorkoutChatConstants.suggestionsCompletedRace
        )
    }

    private static func header(_ info: RaceInfo) -> String {
        let details = [RacesText.distanceText(info.distance), info.city, info.startTime.map { C.startPrefix + $0 }].compactMap { $0 }
        return "\(info.name), \(RacesText.dateText(info.day)), prova \(info.priority.rawValue). " + details.joined(separator: ", ") + "."
    }

    private static func lessonLine(_ prefix: String, _ item: AnalysisItem) -> String {
        prefix + item.text + (item.evidence.map { " (\($0))" } ?? "") + ". " + item.why
    }

    private static func taperLine(_ taper: TaperPlan) -> String {
        let weeks = taper.weeks.map { week in
            String(format: C.taperWeekFormat, week.start.day, week.start.month, TodayText.decimal(week.doneKm, fractionDigits: 1))
                + (week.targetKm.map { String(format: C.taperTargetFormat, TodayText.decimal($0, fractionDigits: 1)) } ?? "")
                + (week.isRaceWeek ? C.raceWeekSuffix : "")
        }
        return String(format: C.taperHeaderFormat, taper.daysLeft, TodayText.decimal(taper.baseKm, fractionDigits: 1)) + weeks.joined(separator: "; ") + "."
    }
}
