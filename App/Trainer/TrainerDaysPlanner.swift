import Insights

enum TrainerDaysPlanner {
    static func runsRange(_ preference: TrainerDayPreference) -> ClosedRange<Int> {
        let range = TrainerDayPreference.runsRange
        let free = TrainerConstants.weekdayCount - preference.offDays.subtracting([preference.longDay]).count
        return range.lowerBound...max(range.lowerBound, min(range.upperBound, free))
    }

    static func togglingOff(_ preference: TrainerDayPreference, weekday: Int) -> TrainerDayPreference {
        var next = preference
        if next.offDays.contains(weekday) {
            next.offDays.remove(weekday)
            return next
        }
        guard weekday != preference.longDay,
              TrainerConstants.weekdayCount - next.offDays.count - 1 >= TrainerDaysConstants.minimumRunDays else { return preference }
        next.offDays.insert(weekday)
        next.runs = min(next.runs, runsRange(next).upperBound)
        return next
    }

    static func choosingLong(_ preference: TrainerDayPreference, weekday: Int) -> TrainerDayPreference {
        var next = preference
        next.longDay = weekday
        next.offDays.remove(weekday)
        return next
    }

    static func settingRuns(_ preference: TrainerDayPreference, runs: Int) -> TrainerDayPreference {
        var next = preference
        let range = runsRange(preference)
        next.runs = min(max(runs, range.lowerBound), range.upperBound)
        return next
    }

    static func warnedDays(_ warnings: [TrainerDayWarning]) -> Set<Int> {
        Set(warnings.filter { !$0.isSoft }.flatMap(\.days))
    }
}
