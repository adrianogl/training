import Foundation
import Metrics
import Projections
import Reports
import Storage
import SwiftData
import TrainingCore

public func targetRace(in context: ModelContext, today: Day) throws -> RaceRecord? {
    let upcoming = try context.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.deletedAt == nil }))
        .compactMap { race in Day(iso: race.day).flatMap { $0 >= today ? (race, $0) : nil } }
        .sorted { $0.1 < $1.1 }
    return (upcoming.first { $0.0.priorityLevel == .a } ?? upcoming.first)?.0
}

public func raceOutlook(context: ModelContext, today: Day) throws -> RaceOutlook {
    raceOutlook(race: try targetRace(in: context, today: today), efforts: try raceEfforts(context: context, today: today), today: today)
}

public func raceEfforts(context: ModelContext, today: Day) throws -> [Effort] {
    let activities = try fetchActivities(context, since: today.adding(days: -InsightsConstants.raceHistoryDays), through: today)
    return try ReportBuilder(context: context, today: today).efforts(from: activities)
}

func raceOutlook(race: RaceRecord?, efforts: [Effort], today: Day) -> RaceOutlook {
    raceOutlook(
        distance: race?.distance ?? 0,
        raceDay: race.flatMap { Day(iso: $0.day) },
        goalSeconds: race?.goalSeconds,
        efforts: efforts,
        today: today
    )
}

public func raceOutlook(distance raceDistance: Double, raceDay upcoming: Day?, goalSeconds: Double?, efforts: [Effort], today: Day) -> RaceOutlook {
    typealias C = InsightsConstants
    let raceDay = upcoming.flatMap { $0 >= today ? $0 : nil }
    let distance = raceDistance > 0 ? raceDistance : C.defaultRaceDistance
    let goal = goalSeconds.flatMap { $0 > 0 ? $0 : nil }
    let series = chunkedPredictionSeries(distance: distance, efforts: efforts, from: today.adding(days: -C.yearDays), to: today)
    let current = predict(distance: distance, efforts: efforts, on: today)
    let displayDays = raceDay.map { today.days(until: $0) } ?? C.raceProjectionFallbackDays
    let projected = project(series, today: today, horizonDays: max(displayDays, C.goalHorizonDays), target: goal)
    let points = Array((projected?.points ?? []).prefix(displayDays))
    let racePoint = raceDay.flatMap { day in
        day == today ? current.map { ProjectionPoint(day: day, mid: $0, low: $0, high: $0) } : points.first { $0.day == day }
    }
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

public func strategyTarget(race: RaceRecord, outlook: RaceOutlook, today: Day, context: ModelContext) throws -> StrategyTarget? {
    if let frozen = race.frozenTargetSeconds, frozen > 0 {
        return StrategyTarget(seconds: frozen, source: .frozen, frozenOn: race.frozenTargetDay.flatMap(Day.init(iso:)))
    }
    let current: StrategyTarget? = if let mid = outlook.raceDay?.mid {
        StrategyTarget(seconds: mid, source: .raceDayProjection, frozenOn: nil)
    } else if let prediction = outlook.today {
        StrategyTarget(seconds: prediction, source: .todayPrediction, frozenOn: nil)
    } else if let goal = race.goalSeconds, goal > 0 {
        StrategyTarget(seconds: goal, source: .goal, frozenOn: nil)
    } else {
        nil
    }
    guard let current, let raceDay = Day(iso: race.day), today == raceDay.adding(days: -1) else { return current }
    race.frozenTargetSeconds = current.seconds
    race.frozenTargetDay = today.iso
    race.updatedAt = .now
    try context.save()
    return StrategyTarget(seconds: current.seconds, source: .frozen, frozenOn: today)
}

func goalCrossing(goal: Double?, projection: Projection?, today: Double?) -> GoalCrossing {
    guard let goal else { return .noGoal }
    let points = projection?.points ?? []
    let improving = points.count >= 2 && points[1].mid < points[0].mid
    if let crossing = projection?.targetCrossing, improving { return .on(crossing) }
    guard let latest = points.first?.mid ?? today else { return .unreachable }
    return latest <= goal ? .alreadyBeaten : .unreachable
}

public func freezeEveTargets(in context: ModelContext, today: Day) throws {
    let tomorrow = today.adding(days: 1).iso
    let races = try context.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.day == tomorrow && $0.deletedAt == nil }))
        .filter { $0.frozenTargetSeconds == nil }
    guard !races.isEmpty else { return }
    let efforts = try raceEfforts(context: context, today: today)
    for race in races {
        let outlook = raceOutlook(distance: race.distance, raceDay: Day(iso: race.day), goalSeconds: race.goalSeconds, efforts: efforts, today: today)
        _ = try strategyTarget(race: race, outlook: outlook, today: today, context: context)
    }
}
