import FITReader
import Foundation
import Metrics
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

public struct ReportBuilder {
    let context: ModelContext
    let today: Day
    let memo: ReportMemo

    public init(context: ModelContext, today: Day, memo: ReportMemo = ReportMemo()) {
        self.context = context
        self.today = today
        self.memo = memo
    }

    public func build() throws -> TrainingReport {
        let activities = try context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        let runs = activities.filter { $0.hasStart && ActivityTypeKey.isRun($0.typeKey) }
        let todayRecord = try dailyRecord(on: today)
        let load = dailyLoad(activities)
        let fff = fitnessFatigueFormToday(load)
        let efforts = try efforts(from: activities)
        return TrainingReport(
            days: try context.fetchCount(FetchDescriptor<DailyRecord>()),
            activities: activities.count,
            today: today,
            readinessScore: todayRecord?.readinessScore,
            readinessPartial: todayRecord?.readinessPartial ?? false,
            vo2max: currentVo2max(runs),
            fitness: fff?.fitness,
            fatigue: fff?.fatigue,
            form: fff?.form,
            acuteChronic: acuteChronicRatio(dailyLoad: load, on: today),
            predictions: predictions(efforts),
            durability: median(of: values(in: runs.filter(Self.isContinuous), metric: decoupling).prefix(ReportConstants.durabilityRuns)),
            hillStrength: median(of: values(in: runs, metric: hillIndex).prefix {
                $0.day >= today.adding(days: -ReportConstants.hillStrengthDays)
            })
        )
    }

    private func dailyRecord(on day: Day) throws -> DailyRecord? {
        let key = day.iso
        return try context.fetch(FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == key })).first
    }

    private func day(of date: Date) -> Day {
        Day.today(in: .current, now: date)
    }

    public func predictions(_ efforts: [Effort]) -> [Prediction] {
        ReportConstants.predictionDistances.map {
            Prediction(
                label: $0.label,
                seconds: predict(distance: $0.meters, efforts: efforts, on: today),
                yearAgoSeconds: predict(distance: $0.meters, efforts: efforts, on: today.adding(days: -ReportConstants.yearDays))
            )
        }
    }

    public func dailyLoad(_ activities: [ActivityRecord]) -> [Day: Double] {
        var load: [Day: Double] = [:]
        for activity in activities where activity.hasStart {
            guard let value = activity.activityTrainingLoad else { continue }
            load[day(of: activity.start), default: 0] += value
        }
        return load
    }

    private func fitnessFatigueFormToday(_ load: [Day: Double]) -> FFFPoint? {
        guard let first = load.keys.min(), first <= today else { return nil }
        return fitnessFatigueForm(dailyLoad: load, from: first, to: today).last
    }

    private func currentVo2max(_ runs: [ActivityRecord]) -> DatedValue? {
        let values = runs.compactMap { run in run.vo2max.map { (day(of: run.start), $0) } }
        return smoothedVo2max(values).last.map { DatedValue(day: $0.0, value: $0.1) }
    }

    public func efforts() throws -> [Effort] {
        try efforts(from: context.fetch(FetchDescriptor<ActivityRecord>()))
    }

    public func efforts(from all: [ActivityRecord]) throws -> [Effort] {
        try memo.efforts(for: all.map(\.activityId)) { try computeEfforts(from: all) }
    }

    private func computeEfforts(from all: [ActivityRecord]) throws -> [Effort] {
        var efforts: [Effort] = []
        for run in all where run.hasStart && ActivityTypeKey.isRun(run.typeKey) {
            let runDay = day(of: run.start)
            if let seconds = run.fastestSplit_5000, seconds > 0 {
                efforts.append(Effort(distance: ReportConstants.split5kMeters, seconds: seconds, day: runDay, kind: .split5k))
            }
            if let seconds = run.fastestSplit_1000, seconds > 0 {
                efforts.append(Effort(distance: ReportConstants.split1kMeters, seconds: seconds, day: runDay, kind: .split1k))
            }
        }
        efforts += try trainingEfforts(from: all)
        let byId = Dictionary(all.map { ($0.activityId, $0) }, uniquingKeysWith: { first, _ in first })
        for race in try context.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.deletedAt == nil })) {
            guard let id = race.resultActivityId, let activity = byId[id], let seconds = activity.duration, seconds > 0 else { continue }
            guard let distance = activity.distance, distance > 0 else { continue }
            efforts.append(Effort(distance: distance, seconds: seconds, day: day(of: activity.start), kind: .race))
        }
        return efforts
    }

    private func trainingEfforts(from all: [ActivityRecord]) throws -> [Effort] {
        let sessions = try trainingSessions(from: all)
        return [TrainingEffortConstants.threshold, TrainingEffortConstants.interval].compactMap { rule in
            trainingEffort(rule, sessions: sessions[rule.runKind] ?? [], today: today)
        }
    }

    public func thresholdSessions(from all: [ActivityRecord]) throws -> [TrainingSession] {
        try trainingSessions(from: all)[TrainingEffortConstants.threshold.runKind] ?? []
    }

    private func trainingSessions(from all: [ActivityRecord]) throws -> [RunKind: [TrainingSession]] {
        try memo.sessions(for: all.map(\.activityId)) { try computeTrainingSessions(from: all) }
    }

    private func computeTrainingSessions(from all: [ActivityRecord]) throws -> [RunKind: [TrainingSession]] {
        let raceKms = try context.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.deletedAt == nil })).map { $0.distance / ReportConstants.metersPerKilometer }
        var sessions: [RunKind: [TrainingSession]] = [:]
        for run in all where run.hasStart && ActivityTypeKey.isRun(run.typeKey) {
            let kind = classifyRun(run, longGoalKm: nil, raceGoalKms: raceKms)
            guard kind == .tempo || kind == .intervals, let work = workPace(run) else { continue }
            sessions[kind, default: []].append(TrainingSession(day: day(of: run.start), work: work))
        }
        return sessions
    }

    public static func isContinuous(_ run: ActivityRecord) -> Bool {
        (run.anaerobicTrainingEffect ?? 0) < ReportConstants.intervalAnaerobicEffect
    }

    private func values(in runs: [ActivityRecord], metric: @escaping ([FITSample]) -> Double?) -> some Sequence<DatedValue> {
        let decoder = JSONDecoder()
        return runs.lazy.compactMap { run in
            guard let data = run.samplesData,
                  let samples = try? decoder.decode([FITSample].self, from: data),
                  let value = metric(samples)
            else { return nil }
            return DatedValue(day: day(of: run.start), value: value)
        }
    }

    private func median<S: Sequence>(of values: S) -> DatedValue? where S.Element == DatedValue {
        let collected = Array(values)
        guard let latest = collected.first, let value = Metrics.median(collected.map(\.value)) else { return nil }
        return DatedValue(day: latest.day, value: value)
    }
}
