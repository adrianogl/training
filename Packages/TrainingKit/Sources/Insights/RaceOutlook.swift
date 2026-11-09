import Metrics
import Projections
import Reports
import Storage
import SwiftData
import TrainingCore

public func targetRace(in context: ModelContext, today: Day) throws -> RaceRecord? {
    let upcoming = try context.fetch(FetchDescriptor<RaceRecord>())
        .compactMap { race in Day(iso: race.day).flatMap { $0 > today ? (race, $0) : nil } }
        .sorted { $0.1 < $1.1 }
    return (upcoming.first { $0.0.priorityLevel == .a } ?? upcoming.first)?.0
}

public func raceOutlook(context: ModelContext, today: Day) throws -> RaceOutlook {
    let activities = try fetchActivities(context, since: today.adding(days: -InsightsConstants.raceHistoryDays), through: today)
    let efforts = try ReportBuilder(context: context, today: today).efforts(from: activities)
    return raceOutlook(race: try targetRace(in: context, today: today), efforts: efforts, today: today)
}

func raceOutlook(race: RaceRecord?, efforts: [Effort], today: Day) -> RaceOutlook {
    typealias C = InsightsConstants
    let raceDay = race.flatMap { Day(iso: $0.day) }.flatMap { $0 > today ? $0 : nil }
    let distance = race.flatMap { $0.distance > 0 ? $0.distance : nil } ?? C.defaultRaceDistance
    let goal = race?.goalSeconds.flatMap { $0 > 0 ? $0 : nil }
    let series = chunkedPredictionSeries(distance: distance, efforts: efforts, from: today.adding(days: -C.yearDays), to: today)
    let current = predict(distance: distance, efforts: efforts, on: today)
    let displayDays = raceDay.map { today.days(until: $0) } ?? C.raceProjectionFallbackDays
    let projected = project(series, today: today, horizonDays: max(displayDays, C.goalHorizonDays), target: goal)
    let points = Array((projected?.points ?? []).prefix(displayDays))
    let racePoint = raceDay.flatMap { day in points.first { $0.day == day } }
    let reference = racePoint?.mid ?? current
    return RaceOutlook(
        distance: distance,
        label: distanceLabel(distance),
        today: current,
        raceDay: racePoint,
        yearAgo: predict(distance: distance, efforts: efforts, on: today.adding(days: -C.yearDays)),
        series: series,
        projection: points,
        longProjection: projected?.points ?? [],
        goalSeconds: goal,
        goalCrossing: goalCrossing(goal: goal, projection: projected, today: current),
        assessment: goal.flatMap { goal in reference.flatMap { assessGoal(goalSeconds: goal, predictionSeconds: $0) } }
    )
}

func goalCrossing(goal: Double?, projection: Projection?, today: Double?) -> GoalCrossing {
    guard let goal else { return .noGoal }
    let points = projection?.points ?? []
    let improving = points.count >= 2 && points[1].mid < points[0].mid
    if let crossing = projection?.targetCrossing, improving { return .on(crossing) }
    guard let latest = points.first?.mid ?? today else { return .unreachable }
    return latest <= goal ? .alreadyBeaten : .unreachable
}
