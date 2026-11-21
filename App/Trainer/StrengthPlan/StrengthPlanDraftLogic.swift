import Foundation
import Insights
import TrainingCore

enum StrengthPlanDraftLogic {
    static func empty(objective: StrengthObjective, today: Day, race: TrainerRaceOption?, now: Date = .now) -> StrengthPlanDraft {
        StrengthPlanDraft(
            id: UUID(), objective: objective, sessions: [], start: today, mode: .weeks, weeks: StrengthPlanUIConstants.defaultWeeks,
            untilDate: today.adding(days: StrengthPlanUIConstants.defaultWeeks * Insights.StrengthPlanConstants.daysPerWeek - 1),
            race: race, builder: .trainer, createdAt: now, endedNotifiedAt: nil, startEdited: false, isNew: true
        )
    }

    static func draft(from plan: StrengthPlan, race: TrainerRaceOption?, targetRace: TrainerRaceOption?) -> StrengthPlanDraft {
        var draft = StrengthPlanDraft(
            id: plan.id, objective: plan.objective, sessions: plan.sessions.filter { $0.source == .trainer }, start: plan.start,
            mode: .weeks, weeks: StrengthPlanUIConstants.defaultWeeks, untilDate: plan.end, race: targetRace, builder: plan.builder,
            createdAt: plan.createdAt, endedNotifiedAt: plan.endedNotifiedAt, startEdited: true, isNew: false
        )
        switch plan.validity {
        case .weeks(let count):
            draft.weeks = count
        case .untilDate:
            draft.mode = .untilDate
        case .untilRace:
            if let race {
                draft.mode = .untilRace
                draft.race = race
            } else {
                draft.mode = .untilDate
            }
        }
        return draft
    }

    static func newSession(objective: StrengthObjective, weekday: Int) -> TrainerStrengthSession {
        let group: TrainerStrengthGroup
        let intensity: TrainerStrengthIntensity
        let minutes: Int
        let place: StrengthPlace
        switch objective {
        case .mobility: (group, intensity, minutes, place) = (.mobility, .light, 20, .home)
        case .strength: (group, intensity, minutes, place) = (.fullBody, .moderate, 45, .gym)
        case .prevention: (group, intensity, minutes, place) = (.fullBody, .light, 30, .gym)
        }
        return TrainerStrengthSession(
            weekday: weekday, group: group, legLoad: StrengthSessions.legLoad(group: group, intensity: intensity),
            name: TrainerStrengthText.focusName(group), source: .trainer, intensity: intensity, minutes: minutes, place: place
        )
    }

    static func date(_ day: Day) -> Date {
        Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .now
    }

    static func nextFreeWeekday(_ sessions: [TrainerStrengthSession]) -> Int? {
        let used = Set(sessions.map(\.weekday))
        return (1...Insights.StrengthPlanConstants.daysPerWeek).first { !used.contains($0) }
    }

    static func defaultStart(_ sessions: [TrainerStrengthSession], today: Day) -> Day {
        StrengthPlan.firstSessionDay(weekdays: Set(sessions.map(\.weekday)), from: today) ?? today
    }

    static func validity(_ draft: StrengthPlanDraft) -> StrengthPlanValidity? {
        switch draft.mode {
        case .weeks: .weeks(draft.weeks)
        case .untilDate: .untilDate(max(draft.untilDate, draft.start))
        case .untilRace: draft.race.map { .untilRace(raceId: $0.id.uuidString, raceDay: $0.day) }
        }
    }

    static func plan(_ draft: StrengthPlanDraft, migrated: Bool = false) -> StrengthPlan? {
        guard !draft.sessions.isEmpty, let validity = validity(draft) else { return nil }
        return StrengthPlan(
            id: draft.id, objective: draft.objective, sessions: draft.sessions.sorted { $0.weekday < $1.weekday }, start: draft.start,
            validity: validity, builder: draft.builder, createdAt: draft.createdAt, endedNotifiedAt: draft.endedNotifiedAt, migrated: migrated
        )
    }

    static func cardSummary(_ plan: StrengthPlan, done: Int, today: Day) -> StrengthPlanCardSummary {
        let planned = plan.plannedCount()
        return StrengthPlanCardSummary(
            label: StrengthPlanText.cardLabel, builder: StrengthPlanText.builderName(plan.builder), title: StrengthPlanText.cardTitle(plan),
            period: StrengthPlanText.cardPeriod(plan), share: planned == 0 ? 0 : Double(done) / Double(planned),
            progress: StrengthPlanText.progress(week: plan.week(on: today), weeks: plan.totalWeeks, done: done, planned: planned)
        )
    }

    static func endedSummary(_ plan: StrengthPlan, done: Int) -> StrengthPlanEndedSummary {
        StrengthPlanEndedSummary(
            title: StrengthPlanText.endedTitle(plan.objective, end: plan.end),
            body: StrengthPlanText.endedBody(done: done, planned: plan.plannedCount(), weekdays: plan.weekdays)
        )
    }

    static func mfitSummary(_ sessions: [TrainerStrengthSession], ended: Bool) -> StrengthMFITSummary? {
        guard !sessions.isEmpty else { return nil }
        return StrengthMFITSummary(title: StrengthPlanText.mfitTitle(sessions), subtitle: StrengthPlanText.mfitSubtitle(sessions, ended: ended))
    }
}
