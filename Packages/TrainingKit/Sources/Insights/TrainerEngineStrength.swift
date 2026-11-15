import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    public static func detectStrength(history: TrainerHistory, today: Day) -> [TrainerStrengthSession] {
        let since = today.adding(days: -C.strengthWindowDays)
        let recent = history.strength.filter { $0.day > since && $0.day <= today }
        let byWeekday = Dictionary(grouping: recent) { weekdayNumber($0.day) }
        return byWeekday.keys.sorted().compactMap { weekday in
            let items = byWeekday[weekday] ?? []
            guard Set(items.map(\.day)).count >= C.strengthMinimumDays else { return nil }
            let name = mostCommon(items.map(\.name))
            let kind = classifyStrength(name: name)
            return TrainerStrengthSession(
                weekday: weekday, group: kind.group, legLoad: kind.load,
                name: kind.matched ? T.strengthGroupName(kind.group) : name
            )
        }
    }

    public static func strengthStatus(
        day: Day, plan: TrainerPlan, history: TrainerHistory
    ) -> [(session: TrainerStrengthSession, done: TrainerStrengthDone?)] {
        let weekday = weekdayNumber(day)
        let done = history.strength.first { $0.day == day }
        return plan.strength.filter { $0.weekday == weekday }.map { (session: $0, done: done) }
    }

    public static func strengthWeeksDone(_ session: TrainerStrengthSession, history: TrainerHistory, today: Day) -> Int {
        let since = today.adding(days: -C.strengthWindowDays)
        let days = history.strength.filter { $0.day > since && $0.day <= today && weekdayNumber($0.day) == session.weekday }.map(\.day)
        return Set(days).count
    }

    static func weekdayNumber(_ day: Day) -> Int {
        day.weekStart.days(until: day) + 1
    }

    static func sessions(before day: Day, in strength: [TrainerStrengthSession]) -> [TrainerStrengthSession] {
        let weekday = weekdayNumber(day.adding(days: -1))
        return strength.filter { $0.weekday == weekday }
    }

    static func isLegHeavy(_ session: TrainerStrengthSession) -> Bool {
        session.legLoad == .heavy || session.group == .lower
    }

    static func legsName(before day: Day, plan: TrainerPlan, history: TrainerHistory) -> String? {
        let eve = day.adding(days: -1)
        if let done = history.strength.first(where: { $0.day == eve }) {
            let kind = classifyStrength(name: done.name)
            if kind.load == .heavy || kind.group == .lower { return done.name }
        }
        return sessions(before: day, in: plan.strength).first(where: isLegHeavy)?.name
    }

    static func classifyStrength(name: String) -> TrainerStrengthKind {
        let normalized = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        func matches(_ words: [String]) -> Bool { words.contains { normalized.contains($0) } }
        if matches(C.lowerWords) { return TrainerStrengthKind(group: .lower, load: .heavy, matched: true) }
        if matches(C.upperWords) { return TrainerStrengthKind(group: .upper, load: .light, matched: true) }
        if matches(C.fullBodyWords) { return TrainerStrengthKind(group: .fullBody, load: .light, matched: true) }
        if matches(C.coreWords) { return TrainerStrengthKind(group: .core, load: .light, matched: true) }
        return TrainerStrengthKind(group: .fullBody, load: .light, matched: false)
    }

    static func longWorkout(
        day: Day, week: TrainerWeek, paces: TrainerPaces, note: String?, slowStart: String?, rationale: String
    ) -> TrainerWorkout {
        let title = T.title(kind: .long, meters: week.longMeters)
        guard slowStart != nil, week.longMeters > C.slowStartMeters else {
            return steadyWorkout(
                day: day, kind: .long, meters: week.longMeters, pace: paces.long, band: C.easyBand, title: title,
                note: note, rationale: rationale
            )
        }
        let normal = band(paces.long, C.easyBand)
        let slow = band(paces.long + C.slowStartSeconds, C.easyBand)
        let steps = [
            TrainerStep(kind: .steady, meters: C.slowStartMeters, paceLow: slow.low, paceHigh: slow.high),
            TrainerStep(kind: .steady, meters: week.longMeters - C.slowStartMeters, paceLow: normal.low, paceHigh: normal.high),
        ]
        let joined = [note, T.slowStartNote].compactMap { $0 }.joined(separator: " · ")
        return TrainerWorkout(
            day: day, kind: .long, title: title, totalMeters: week.longMeters, steps: steps,
            paceLow: normal.low, paceHigh: normal.high, note: joined, rationale: rationale
        )
    }

    private static func mostCommon(_ names: [String]) -> String {
        let counts = Dictionary(grouping: names) { $0 }.mapValues(\.count)
        return counts.max { left, right in
            left.value != right.value ? left.value < right.value : left.key > right.key
        }?.key ?? ""
    }

    static func withPlannedMeters(
        _ weeks: [TrainerWeek], workouts: [TrainerWorkout], structure: [Int: TrainerDayKind], target: TrainerTarget,
        history: TrainerHistory, today: Day
    ) -> [TrainerWeek] {
        weeks.map { week in
            guard week.start >= today.weekStart else { return week }
            var result = week
            result.plannedMeters = (1...C.daysPerWeek).reduce(0.0) { total, weekday in
                let day = week.start.adding(days: weekday - 1)
                guard let workout = workouts.first(where: { $0.day == day }) else {
                    return total + estimatedMeters(
                        weekday: weekday, day: day, week: week, structure: structure, target: target, history: history, today: today
                    )
                }
                return total + workout.totalMeters
            }
            return result
        }
    }

    private static func estimatedMeters(
        weekday: Int, day: Day, week: TrainerWeek, structure: [Int: TrainerDayKind], target: TrainerTarget,
        history: TrainerHistory, today: Day
    ) -> Double {
        let kind = structure[weekday] ?? .off
        if let raceDay = target.date, raceDay.weekStart == week.start {
            if day == raceDay { return target.distanceMeters ?? 0 }
            return day > raceDay || kind == .off || kind == .optionalEasy ? 0 : C.raceWeekEasyMeters
        }
        switch kind {
        case .long: return week.longMeters
        case .threshold, .vo2max: return qualityMeters(qualityStage(kind, week: week, lowered: false))
        case .easy: return easyShare(week: week, structure: structure, history: history, today: today).meters
        case .optionalEasy: return easyShare(week: week, structure: structure, history: history, today: today).optional
        case .off, .race: return 0
        }
    }
}
