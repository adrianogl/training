import FITReader
import Foundation
import Metrics
import Storage
import SwiftData
import TrainingCore

public struct ReportBuilder {
    let context: ModelContext
    let today: Day

    public init(context: ModelContext, today: Day) {
        self.context = context
        self.today = today
    }

    public func build() throws -> TrainingReport {
        let activities = try context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        let runs = activities.filter { $0.typeKey.contains(ReportConstants.runTypeKeyMarker) }
        let todayRecord = try dailyRecord(on: today)
        let load = dailyLoad(activities)
        let fff = fitnessFatigueFormToday(load)
        let efforts = try efforts(runs: runs, all: activities)
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
            predictions: ReportConstants.predictionDistances.map {
                Prediction(label: $0.label, seconds: predict(distance: $0.meters, efforts: efforts, on: today))
            },
            durability: latest(in: runs.filter(isContinuous), metric: decoupling),
            hillStrength: latest(in: runs, metric: hillIndex)
        )
    }

    private func dailyRecord(on day: Day) throws -> DailyRecord? {
        let key = day.iso
        return try context.fetch(FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == key })).first
    }

    private func day(of date: Date) -> Day {
        Day.today(in: .current, now: date)
    }

    private func dailyLoad(_ activities: [ActivityRecord]) -> [Day: Double] {
        var load: [Day: Double] = [:]
        for activity in activities {
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

    private func efforts(runs: [ActivityRecord], all: [ActivityRecord]) throws -> [Effort] {
        var efforts: [Effort] = []
        for run in runs {
            let runDay = day(of: run.start)
            if let seconds = run.fastestSplit_5000, seconds > 0 {
                efforts.append(Effort(distance: ReportConstants.split5kMeters, seconds: seconds, day: runDay, kind: .split5k))
            }
            if let seconds = run.fastestSplit_1000, seconds > 0 {
                efforts.append(Effort(distance: ReportConstants.split1kMeters, seconds: seconds, day: runDay, kind: .split1k))
            }
        }
        let byId = Dictionary(all.map { ($0.activityId, $0) }, uniquingKeysWith: { first, _ in first })
        for race in try context.fetch(FetchDescriptor<RaceRecord>()) {
            guard let id = race.resultActivityId, let activity = byId[id], let seconds = activity.duration, seconds > 0 else { continue }
            let distance = race.distance > 0 ? race.distance : (activity.distance ?? 0)
            efforts.append(Effort(distance: distance, seconds: seconds, day: day(of: activity.start), kind: .race))
        }
        return efforts
    }

    private func isContinuous(_ run: ActivityRecord) -> Bool {
        (run.anaerobicTrainingEffect ?? 0) < ReportConstants.intervalAnaerobicEffect
    }

    private func latest(in runs: [ActivityRecord], metric: ([FITSample]) -> Double?) -> DatedValue? {
        let decoder = JSONDecoder()
        for run in runs {
            guard let data = run.samplesData,
                  let samples = try? decoder.decode([FITSample].self, from: data),
                  let value = metric(samples)
            else { continue }
            return DatedValue(day: day(of: run.start), value: value)
        }
        return nil
    }
}
