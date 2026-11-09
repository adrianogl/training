import Metrics
import Reports
import Storage
import SwiftData
import Sync
import TrainingCore

public func todaySummary(context: ModelContext, today: Day) throws -> TodaySummary {
    typealias C = InsightsConstants
    let activities = try fetchActivities(context, since: today.adding(days: -C.raceHistoryDays), through: today)
    let builder = ReportBuilder(context: context, today: today)
    let load = builder.dailyLoad(activities)
    let efforts = try builder.efforts(from: activities)
    let race = try targetRace(in: context, today: today)
    let raceDay = race.flatMap { Day(iso: $0.day) }
    let records = Dictionary(
        try fetchDaily(context, since: today.adding(days: -C.readinessHistoryDays), through: today),
        uniquingKeysWith: { first, _ in first }
    )
    func input(on day: Day) -> ReadinessInput? {
        records[day]?.readinessInput(acuteChronic: acuteChronicRatio(dailyLoad: load, on: day.adding(days: -1)))
    }
    let todayInput = input(on: today)
    let history = (1...C.readinessHistoryDays).reversed().compactMap { input(on: today.adding(days: -$0)) }
    let runs = activities.filter(isRun)
    return TodaySummary(
        readiness: todayInput.flatMap { readinessBreakdown(today: $0, history: history) },
        verdict: todayInput.flatMap(readiness)?.verdict,
        supporting: ReadinessSupport(
            hrvVsBaseline: records[today].flatMap(hrvVsBaseline),
            sleepScore: records[today]?.sleepScore,
            acuteChronic: acuteChronicRatio(dailyLoad: load, on: today.adding(days: -1)),
            stress: records[today]?.stressAvg
        ),
        fitness: fitnessOutlook(dailyLoad: load, today: today, raceDay: raceDay),
        race: raceOutlook(race: race, efforts: efforts, today: today),
        raceCountdownDays: raceDay.map { today.days(until: $0) },
        racePriority: race?.priorityLevel,
        week: weekVolume(runs, today: today),
        predictions: builder.predictions(efforts),
        lastRunId: runs.last?.activityId
    )
}

func hrvVsBaseline(_ record: DailyRecord) -> Double? {
    guard let value = record.hrvLastNight, let low = record.hrvBalancedLow, let high = record.hrvBalancedUpper else { return nil }
    return value - (low + high) / 2
}

func weekVolume(_ runs: [ActivityRecord], today: Day) -> WeekVolume {
    typealias C = InsightsConstants
    var km: [Day: Double] = [:]
    for run in runs {
        km[activityDay(run), default: 0] += (run.distance ?? 0) / C.metersPerKm
    }
    let start = today.weekStart
    var perDay: [Day: Double] = [:]
    var day = start
    while day <= today {
        perDay[day] = km[day] ?? 0
        day = day.adding(days: 1)
    }
    func total(weekStarting first: Day) -> Double {
        (0..<C.daysPerWeek).reduce(0) { $0 + (km[first.adding(days: $1)] ?? 0) }
    }
    let previous = (1...C.previousWeeks).map { total(weekStarting: start.adding(days: -C.daysPerWeek * $0)) }
    return WeekVolume(
        perDay: perDay,
        total: perDay.values.reduce(0, +),
        lastWeek: previous.first ?? 0,
        average4Weeks: previous.reduce(0, +) / Double(C.previousWeeks)
    )
}
