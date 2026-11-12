import Metrics
import Narrative
import Reports
import Storage
import SwiftData
import Sync
import TrainingCore

public func overallState(context: ModelContext, today: Day) throws -> OverallState {
    typealias C = InsightsConstants
    let activities = try fetchActivities(context, since: nil, through: today)
    let builder = ReportBuilder(context: context, today: today)
    let efforts = try builder.efforts(from: activities)
    let outlook = raceOutlook(race: try targetRace(in: context, today: today), efforts: efforts, today: today)
    let runs = activities.filter(isRun)
    var zone2ByDay: [Day: ClosedRange<Int>] = [:]
    for day in Set(runs.map(activityDay)).union([today]) {
        zone2ByDay[day] = zone2Range(try runningZones(on: day, context))
    }
    let source = IndicatorSource(
        runs: runs,
        load: builder.dailyLoad(activities),
        efforts: efforts,
        distance: outlook.distance,
        thresholdHeartRate: try thresholdHeartRate(on: today, in: context),
        zone2ByDay: zone2ByDay,
        today: today
    )
    let past = today.adding(days: -C.comparisonDays)
    let goalGap = outlook.goalSeconds.flatMap { goal in outlook.today.map { $0 - goal } }
    let indicators = IndicatorKind.allCases.map { kind -> Indicator in
        let now = source.value(kind, on: today)
        let before = source.value(kind, on: past)
        let delta = now.flatMap { now in before.map { now - $0 } }
        return Indicator(
            kind: kind,
            today: now,
            delta: delta,
            goalGap: kind == .racePrediction ? goalGap : nil,
            trend: trend(kind, delta: delta, before: before)
        )
    }
    let improved = indicators.filter { $0.trend == .better }.count
    let worsened = indicators.filter { $0.trend == .worse }.count
    let balance = improved - worsened
    let verdict: OverallVerdict = balance >= C.verdictDifference ? .better : balance <= -C.verdictDifference ? .worse : .stable
    return OverallState(
        indicators: indicators,
        facts: OverallFacts(
            verdict: verdict,
            improved: improved,
            worsened: worsened,
            total: indicators.filter { $0.trend != .unknown }.count,
            goalGapSeconds: goalGap,
            raceDayGapSeconds: outlook.goalSeconds.flatMap { goal in outlook.raceDay.map { $0.mid - goal } }
        )
    )
}

func trend(_ kind: IndicatorKind, delta: Double?, before: Double?) -> IndicatorTrend {
    guard let delta, let before, let margin = InsightsConstants.margins[kind] else { return .unknown }
    let threshold = margin.relative ? margin.value * abs(before) : margin.value
    if abs(delta) < threshold { return .same }
    let lowerIsBetter = InsightsConstants.lowerIsBetter.contains(kind)
    return (delta < 0) == lowerIsBetter ? .better : .worse
}

struct IndicatorSource {
    let runs: [ActivityRecord]
    let efforts: [Effort]
    let distance: Double
    let zone2ByDay: [Day: ClosedRange<Int>]
    let thresholdHeartRate: Int?
    let vo2max: [(Day, Double)]
    let fitness: [Day: Double]
    let runDays: [Day]

    init(runs: [ActivityRecord], load: [Day: Double], efforts: [Effort], distance: Double, thresholdHeartRate: Int?, zone2ByDay: [Day: ClosedRange<Int>], today: Day) {
        self.runs = runs
        self.efforts = efforts
        self.distance = distance
        self.zone2ByDay = zone2ByDay
        self.thresholdHeartRate = thresholdHeartRate
        vo2max = smoothedVo2max(runs.compactMap { run in run.vo2max.map { (activityDay(run), $0) } })
        var fitness: [Day: Double] = [:]
        if let first = load.keys.min(), first <= today {
            for point in fitnessFatigueForm(dailyLoad: load, from: first, to: today) {
                fitness[point.day] = point.fitness
            }
        }
        self.fitness = fitness
        runDays = runs.map(activityDay)
    }

    func value(_ kind: IndicatorKind, on day: Day) -> Double? {
        typealias C = InsightsConstants
        switch kind {
        case .racePrediction:
            return predict(distance: distance, efforts: efforts, on: day)
        case .vo2max:
            return vo2max.last { $0.0 <= day }?.1
        case .fitness:
            return fitness[day]
        case .zone2Pace:
            return median(window(C.paceWindowDays, endingOn: day).compactMap { run in
                zone2ByDay[activityDay(run)].flatMap { zone2 in samples(of: run).flatMap { zone2Pace($0, zone2: zone2) } }
            })
        case .thresholdPace:
            guard let thresholdHeartRate else { return nil }
            let sampled = window(C.paceWindowDays, endingOn: day).compactMap(samples(of:))
            return thresholdPace(sampled, lthr: thresholdHeartRate)
        case .monthlyVolume:
            guard runDays.contains(where: { $0 <= day }) else { return nil }
            return window(C.volumeWindowDays, endingOn: day).reduce(0) { $0 + ($1.distance ?? 0) } / C.metersPerKm
        }
    }

    private func window(_ days: Int, endingOn day: Day) -> [ActivityRecord] {
        let first = day.adding(days: 1 - days)
        return zip(runs, runDays).filter { $0.1 >= first && $0.1 <= day }.map(\.0)
    }
}
