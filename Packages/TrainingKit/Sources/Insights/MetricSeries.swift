import Foundation
import Metrics
import Projections
import Reports
import Storage
import SwiftData
import Sync
import TrainingCore

public func metricSeries(_ kind: MetricKind, context: ModelContext, today: Day, period: MetricPeriod) throws -> MetricSeries {
    typealias C = InsightsConstants
    let windowStart = period.days.map { today.adding(days: 1 - $0) }
    let lower = windowStart.map { $0.adding(days: -C.yearDays) }
    let raw = try rawMetric(kind, context: context, since: lower, today: today)
    let values = raw.values.filter { point in point.0 <= today && (lower.map { point.0 >= $0 } ?? true) }
    let start = windowStart ?? values.first?.0 ?? today
    let points = values.filter { $0.0 >= start }
    let shiftedLower = start.adding(days: -C.yearDays)
    let shiftedUpper = today.adding(days: -C.yearDays)
    let lastYear = values
        .filter { $0.0 >= shiftedLower && $0.0 <= shiftedUpper }
        .map { ($0.0.adding(days: C.yearDays), $0.1) }
    let raceDay = try targetRace(in: context, today: today).flatMap { Day(iso: $0.day) }
    let horizon = max(C.metricProjectionDays, raceDay.map { today.days(until: $0) } ?? 0)
    let projected = project(points, today: today, horizonDays: horizon)
    let stats = metricStats(points)
    return MetricSeries(
        kind: kind,
        points: points,
        movingAverage7: movingAverage(points, days: C.movingAverageDays),
        normalBand: points.isEmpty ? nil : raw.normalBand,
        projection: Array((projected?.points ?? []).prefix(C.metricProjectionDays)),
        raceDayValue: raceDay.flatMap { day in projected?.points.first { $0.day == day }?.mid },
        stats: stats,
        monthly: monthlyMeans(points),
        lastYear: lastYear,
        reading: reading(kind, stats: stats)
    )
}

func rawMetric(_ kind: MetricKind, context: ModelContext, since lower: Day?, today: Day) throws -> RawMetric {
    typealias C = InsightsConstants
    switch kind {
    case .restingHeartRate:
        return RawMetric(values: try dailyValues(context, since: lower, today: today) { $0.restingHR.map(Double.init) })
    case .sleep:
        return RawMetric(values: try dailyValues(context, since: lower, today: today) { $0.sleepScore.map(Double.init) })
    case .bodyBattery:
        return RawMetric(values: try dailyValues(context, since: lower, today: today) { $0.bodyBatteryMorningMax.map(Double.init) })
    case .hrv:
        let records = try fetchDaily(context, since: lower, through: today)
        let band = records.reversed().lazy.compactMap { _, record -> ClosedRange<Double>? in
            guard let low = record.hrvBalancedLow, let high = record.hrvBalancedUpper, low <= high else { return nil }
            return low...high
        }.first
        return RawMetric(values: records.compactMap { day, record in record.hrvLastNight.map { (day, $0) } }, normalBand: band)
    case .vo2max:
        let runs = try fetchActivities(context, since: nil, through: today).filter(isRun)
        let smoothed = smoothedVo2max(runs.compactMap { run in run.vo2max.map { (activityDay(run), $0) } })
        var latest: [Day: Double] = [:]
        for (day, value) in smoothed { latest[day] = value }
        return RawMetric(values: latest.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 })
    case .fitness:
        let activities = try fetchActivities(context, since: nil, through: today)
        let load = ReportBuilder(context: context, today: today).dailyLoad(activities)
        guard let first = load.keys.min(), first <= today else { return RawMetric(values: []) }
        return RawMetric(values: fitnessFatigueForm(dailyLoad: load, from: first, to: today).map { ($0.day, $0.fitness) })
    case .monthlyVolume:
        let runs = try fetchActivities(context, since: lower?.adding(days: -C.volumeWindowDays), through: today).filter(isRun)
        var km: [Day: Double] = [:]
        for run in runs { km[activityDay(run), default: 0] += (run.distance ?? 0) / C.metersPerKm }
        return RawMetric(values: rolling(keys: Set(km.keys), since: lower, today: today, window: C.volumeWindowDays) { days in
            days.reduce(0) { $0 + (km[$1] ?? 0) }
        })
    case .loadFocus:
        let activities = try fetchActivities(context, since: lower?.adding(days: -C.focusWindowDays), through: today)
        let thresholdAvailable = try hasThreshold(context, today: today)
        var items: [Day: [(load: Double, zoneSeconds: [Double])]] = [:]
        for activity in activities {
            let seconds = focusZoneSeconds(activity, thresholdAvailable: thresholdAvailable)
            guard let load = activity.activityTrainingLoad, seconds.count == C.zoneCount else { continue }
            items[activityDay(activity), default: []].append((load, seconds))
        }
        return RawMetric(values: rolling(keys: Set(items.keys), since: lower, today: today, window: C.focusWindowDays) { days in
            loadFocus(days.flatMap { items[$0] ?? [] }).map { $0.lowAerobic * C.percent }
        })
    case .zoneDistribution:
        let runs = try fetchActivities(context, since: lower?.adding(days: -C.focusWindowDays), through: today).filter(isRun)
        let thresholdAvailable = try hasThreshold(context, today: today)
        var seconds: [Day: [Double]] = [:]
        for run in runs {
            let runSeconds = focusZoneSeconds(run, thresholdAvailable: thresholdAvailable)
            guard runSeconds.count == C.zoneCount else { continue }
            let current = seconds[activityDay(run)] ?? Array(repeating: 0, count: C.zoneCount)
            seconds[activityDay(run)] = zip(current, runSeconds).map { $0 + $1 }
        }
        return RawMetric(values: rolling(keys: Set(seconds.keys), since: lower, today: today, window: C.focusWindowDays) { days in
            let zones = days.compactMap { seconds[$0] }
            let total = zones.reduce(0) { $0 + $1.reduce(0, +) }
            guard total > 0 else { return nil }
            return zones.reduce(0) { $0 + $1.prefix(C.lowZoneCount).reduce(0, +) } / total * C.percent
        })
    case .zone2Pace:
        var zone2ByDay: [Day: ClosedRange<Int>?] = [:]
        return RawMetric(values: try runValues(context, since: lower, today: today) { run in
            let day = activityDay(run)
            if zone2ByDay[day] == nil { zone2ByDay[day] = .some(zone2Range(try runningZones(on: day, context))) }
            guard let zone2 = zone2ByDay[day] ?? nil else { return nil }
            return samples(of: run).flatMap { zone2Pace($0, zone2: zone2) }
        })
    case .thresholdPace:
        guard let lthr = try thresholdHeartRate(on: today, in: context) else { return RawMetric(values: []) }
        return RawMetric(values: try runValues(context, since: lower, today: today) { run in
            samples(of: run).flatMap { thresholdPace([$0], lthr: lthr) }
        })
    case .thresholdHeartRate:
        guard let lthr = try thresholdHeartRate(on: today, in: context) else { return RawMetric(values: []) }
        return RawMetric(values: [(today, Double(lthr))])
    case .durability:
        return RawMetric(values: try runValues(context, since: lower, today: today) { run in
            ReportBuilder.isContinuous(run) ? samples(of: run).flatMap(decoupling) : nil
        })
    case .hillStrength:
        return RawMetric(values: try runValues(context, since: lower, today: today) { samples(of: $0).flatMap(hillIndex) })
    case .cadence:
        return RawMetric(values: try runValues(context, since: lower, today: today) { $0.averageRunningCadenceInStepsPerMinute })
    case .groundContact:
        return RawMetric(values: try runValues(context, since: lower, today: today) { $0.avgGroundContactTime })
    case .verticalOscillation:
        return RawMetric(values: try runValues(context, since: lower, today: today) { $0.avgVerticalOscillation })
    case .prediction5k, .prediction10k, .predictionHalf, .predictionFull:
        guard let distance = C.predictionDistances[kind] else { return RawMetric(values: []) }
        let activities = try fetchActivities(context, since: lower?.adding(days: -C.raceEffortWindowDays), through: today)
        let efforts = try ReportBuilder(context: context, today: today).efforts(from: activities)
        guard let first = lower ?? efforts.map(\.day).min() else { return RawMetric(values: []) }
        return RawMetric(values: chunkedPredictionSeries(distance: distance, efforts: efforts, from: first, to: today))
    }
}

private func dailyValues(_ context: ModelContext, since lower: Day?, today: Day, value: (DailyRecord) -> Double?) throws -> [(Day, Double)] {
    try fetchDaily(context, since: lower, through: today).compactMap { day, record in value(record).map { (day, $0) } }
}

private func runValues(_ context: ModelContext, since lower: Day?, today: Day, value: (ActivityRecord) throws -> Double?) throws -> [(Day, Double)] {
    let runs = try fetchActivities(context, since: lower, through: today).filter(isRun)
    return try dailyMeans(runs.compactMap { run in try value(run).map { (activityDay(run), $0) } })
}

private func rolling(keys: Set<Day>, since lower: Day?, today: Day, window: Int, value: ([Day]) -> Double?) -> [(Day, Double)] {
    guard let earliest = keys.min() else { return [] }
    var day = max(earliest, lower ?? earliest)
    var result: [(Day, Double)] = []
    while day <= today {
        let days = (0..<window).map { day.adding(days: -$0) }
        if let current = value(days) { result.append((day, current)) }
        day = day.adding(days: 1)
    }
    return result
}

func movingAverage(_ points: [(Day, Double)], days: Int) -> [(Day, Double)] {
    var result: [(Day, Double)] = []
    var start = 0
    var sum = 0.0
    for (index, point) in points.enumerated() {
        sum += point.1
        let first = point.0.adding(days: 1 - days)
        while points[start].0 < first {
            sum -= points[start].1
            start += 1
        }
        result.append((point.0, sum / Double(index - start + 1)))
    }
    return result
}

func monthlyMeans(_ points: [(Day, Double)]) -> [(Day, Double)] {
    var groups: [Day: [Double]] = [:]
    for (day, value) in points {
        groups[Day(year: day.year, month: day.month, day: 1), default: []].append(value)
    }
    return groups.compactMap { month, values in average(values).map { (month, $0) } }.sorted { $0.0 < $1.0 }
}

func metricStats(_ points: [(Day, Double)]) -> MetricStats {
    let values = points.map(\.1)
    var change: Double?
    if values.count >= 2, let first = values.first, let last = values.last { change = last - first }
    return MetricStats(current: values.last, average: average(values), minimum: values.min(), maximum: values.max(), change: change)
}

func reading(_ kind: MetricKind, stats: MetricStats) -> String {
    typealias C = InsightsConstants
    guard let current = stats.current, let name = C.metricNames[kind], let format = C.metricFormats[kind] else { return C.noDataReading }
    var direction = C.steady
    if let change = stats.change, let mean = stats.average, abs(change) >= C.stableFraction * abs(mean) {
        direction = change > 0 ? C.rose : C.fell
    }
    return "\(name): \(formatted(current, format)), \(direction) no período."
}

func formatted(_ value: Double, _ format: MetricFormat) -> String {
    switch format {
    case .pace:
        let seconds = Int(value.rounded())
        return String(format: "%d:%02d/km", seconds / 60, seconds % 60)
    case .duration:
        let seconds = Int(value.rounded())
        if seconds >= 3_600 { return String(format: "%d:%02d:%02d", seconds / 3_600, seconds % 3_600 / 60, seconds % 60) }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    case .number(let decimals, let unit):
        return String(format: "%.\(decimals)f", value).replacingOccurrences(of: ".", with: ",") + unit
    }
}
