import FITReader
import Foundation
import Metrics
import Storage
import TrainingCore
import WorkoutAnalysis

private typealias C = DetailedAnalysisConstants

struct PreparedRun {
    let record: ActivityRecord
    let day: Day
    let splits: [DetailedSplit]
    let continuity: RunContinuity?
    let plannedMeters: Double?
    let fadeKm: Int?
    let startPace: Double?
    let drift: Double?
    let meters: Double

    init(_ record: ActivityRecord) {
        self.record = record
        day = Self.day(of: record)
        let samples = record.samplesData.flatMap { try? JSONDecoder().decode([FITSample].self, from: $0) } ?? []
        splits = detailedSplits(samples)
        continuity = runContinuity(samples)
        plannedMeters = Self.plannedMeters(record)
        fadeKm = fadeKilometer(splits.map(\.paceSeconds))
        startPace = openingPace(splits)
        drift = decoupling(splits)
        meters = record.distance ?? continuity?.totalMeters ?? 0
    }

    var averagePace: Double? { average(splits.map(\.paceSeconds)) }
    var averageHeartRate: Double? { average(splits.compactMap(\.heartRate)) }

    static func day(of record: ActivityRecord) -> Day {
        record.localDay.flatMap(Day.init(iso:)) ?? Day.today(now: record.start)
    }

    static func plannedMeters(_ record: ActivityRecord) -> Double? {
        let steps = record.structureData.flatMap { try? JSONDecoder().decode(WorkoutStructure.self, from: $0) }?.prescription?.steps ?? []
        func distance(_ step: PrescribedStep) -> Double? {
            switch (step.duration, step.target) {
            case let (.distance(meters), _): meters
            case let (.time(seconds), .speed(low, high)): seconds * (low + high) / 2
            default: nil
            }
        }
        var total = 0.0
        for step in steps {
            if case let .repeatSteps(fromIndex, count) = step.duration {
                let body = steps.filter { $0.index >= fromIndex && $0.index < step.index }.compactMap(distance).reduce(0, +)
                total += body * Double(max(count - 1, 0))
            } else if let meters = distance(step) {
                total += meters
            } else {
                return nil
            }
        }
        return total > 0 ? total : nil
    }
}

struct DetailedContext {
    let kind: RunKind
    let current: PreparedRun
    let similar: [PreparedRun]
    let currentPercent: Double?
    let similarPercents: [Double?]
    let readiness: [String: Int]
    let runs: [ActivityRecord]
    let goals: [DetailedGoalNote]
    let longGoalKm: Double?
    let raceGoalKms: [Double]

    var knownSimilarPercents: [Double] { similarPercents.compactMap { $0 } }
}

public func detailedAnalysis(
    record: ActivityRecord,
    history: [ActivityRecord],
    daily: [DailyRecord],
    goals: [DetailedGoalNote] = [],
    longGoalKm: Double? = nil,
    raceGoalKms: [Double] = []
) -> DetailedAnalysis? {
    let current = PreparedRun(record)
    guard !current.splits.isEmpty else { return nil }
    let kind = classifyRun(record, longGoalKm: longGoalKm, raceGoalKms: raceGoalKms)
    let windowStart = current.day.adding(days: -C.windowDays)
    let runs = history.filter { ActivityTypeKey.isRun($0.typeKey) && $0.activityId != record.activityId }
    let similarRecords = runs
        .filter { $0.start < record.start && PreparedRun.day(of: $0) >= windowStart && classifyRun($0, longGoalKm: longGoalKm, raceGoalKms: raceGoalKms) == kind }
        .sorted { $0.start > $1.start }
        .prefix(C.maxSimilar)
    let similar = Array(similarRecords.reversed()).map(PreparedRun.init)
    let reference = median(similar.map(\.meters).filter { $0 > 0 })
    func percent(_ run: PreparedRun) -> Double? {
        guard run.meters > 0 else { return nil }
        guard let base = run.plannedMeters ?? reference, base > 0 else { return nil }
        return (run.meters / base * 1_000).rounded() / 10
    }
    let readiness = Dictionary(daily.compactMap { row in row.readinessScore.map { (row.day, $0) } }, uniquingKeysWith: { _, last in last })
    let context = DetailedContext(
        kind: kind, current: current, similar: similar, currentPercent: percent(current), similarPercents: similar.map { percent($0).map { min($0, C.completionCap) } },
        readiness: readiness, runs: runs, goals: goals, longGoalKm: longGoalKm, raceGoalKms: raceGoalKms
    )
    let findings = detailedFindings(context)
    let fadeApplies = C.fadeKinds.contains(kind)
    let driftApplies = C.driftKinds.contains(kind)
    let kpis = DetailedKPIs(
        completionPercent: context.currentPercent,
        completionAverage: average(context.knownSimilarPercents).map(rounded),
        fadeKm: fadeApplies ? current.fadeKm : nil,
        fadeKmAverage: fadeApplies ? average(similar.compactMap { $0.fadeKm.map(Double.init) }).map(rounded) : nil,
        driftPercent: driftApplies ? current.drift.map(rounded) : nil,
        driftAverage: driftApplies ? average(similar.compactMap(\.drift)).map(rounded) : nil
    )
    return DetailedAnalysis(
        kind: kind,
        kpis: kpis,
        splits: current.splits,
        fadeKm: fadeApplies ? current.fadeKm : nil,
        pauseKilometers: (current.continuity?.pauses ?? []).map { $0.startMeters / C.metersPerKilometer },
        current: point(current, percent: context.currentPercent),
        similar: zip(similar, context.similarPercents).map { point($0, percent: $1) },
        windowDays: C.windowDays,
        readinessDays: readiness.keys.compactMap(Day.init(iso:)).filter { $0 >= windowStart && $0 <= current.day }.count,
        findings: findings,
        recommendations: detailedRecommendations(context)
    )
}

private func point(_ run: PreparedRun, percent: Double?) -> DetailedRunPoint {
    DetailedRunPoint(
        activityId: run.record.activityId,
        start: run.record.start,
        percentOfDistance: percent,
        fadeKm: run.fadeKm,
        isComplete: (percent ?? 0) >= C.completeRatio,
        pauseCount: run.continuity?.pauses.count
    )
}

private func rounded(_ value: Double) -> Double {
    (value * 10).rounded() / 10
}
