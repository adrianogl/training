import TrainingCore

public func fitnessOutlook(dailyLoad: [Day: Double], today: Day, raceDay: Day?) -> FitnessOutlook {
    typealias C = RaceConstants
    let historyStart = today.adding(days: 1 - C.outlookHistoryDays)
    let history = fitnessFatigueForm(dailyLoad: dailyLoad, from: historyStart, to: today)

    let recentSum = (0..<C.outlookLoadAverageDays).reduce(0.0) { $0 + (dailyLoad[today.adding(days: -$1)] ?? 0) }
    let dailyAverage = recentSum / Double(C.outlookLoadAverageDays)

    let upcomingRace = raceDay.flatMap { $0 > today ? $0 : nil }
    let projectionDays = upcomingRace.map { today.days(until: $0) } ?? C.outlookProjectionDays

    var extended = dailyLoad
    for offset in 1...projectionDays {
        let day = today.adding(days: offset)
        var load = dailyAverage
        if let upcomingRace {
            let daysToRace = day.days(until: upcomingRace)
            if daysToRace < C.taperDays { load *= 1 - C.taperReduction }
        }
        extended[day] = load
    }

    let all = fitnessFatigueForm(dailyLoad: extended, from: historyStart, to: today.adding(days: projectionDays))
    let projection = Array(all.dropFirst(history.count))
    let raceDayForm = upcomingRace.flatMap { race in projection.first { $0.day == race }?.form }
    return FitnessOutlook(history: history, projection: projection, peakFitness: all.map(\.fitness).max(), raceDayForm: raceDayForm)
}
