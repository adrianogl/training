import Foundation
import Metrics
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static func signals(plan: TrainerPlan, history: TrainerHistory, week: TrainerWeek) -> [TrainerSignal] {
        let weekDays = (0..<C.daysPerWeek).map { week.start.adding(days: $0) }
        let baselineDays = (1...C.signalBaselineDays).map { week.start.adding(days: -$0) }
        let end = weekDays[weekDays.count - 1]
        return TrainerSignal.allCases.filter { signal in
            switch signal {
            case .hrv:
                guard let pair = series(history.hrv, weekDays, baselineDays) else { return false }
                return mean(pair.week) < mean(pair.baseline) - C.signalHrvDeviation * deviation(pair.baseline)
            case .restingHeartRate:
                guard let pair = series(history.restingHeartRate.mapValues(Double.init), weekDays, baselineDays) else { return false }
                return mean(pair.week) >= mean(pair.baseline) + C.signalRestingMargin
            case .sleep:
                guard let pair = series(history.sleepSeconds.mapValues(Double.init), weekDays, baselineDays) else { return false }
                return mean(pair.week) <= mean(pair.baseline) - C.signalSleepMargin
            case .load:
                guard hasLoadData(history.dailyLoad, end: end), let ratio = acuteChronicRatio(dailyLoad: history.dailyLoad, on: end) else { return false }
                return ratio > C.signalLoadRatio
            case .performance:
                return qualityStreakOffTarget(plan: plan, history: history, start: week.start, end: end)
                    || easyHeartRateDrift(history: history, start: week.start, end: end)
            case .readiness:
                let values = weekDays.compactMap { history.readiness[$0] }.map(Double.init)
                guard values.count >= C.signalMinimumWeekDays else { return false }
                return mean(values) < C.readinessWeek
            }
        }
    }

    private static func series(
        _ values: [Day: Double], _ weekDays: [Day], _ baselineDays: [Day]
    ) -> (week: [Double], baseline: [Double])? {
        let week = weekDays.compactMap { values[$0] }
        let baseline = baselineDays.compactMap { values[$0] }
        guard week.count >= C.signalMinimumWeekDays, baseline.count >= C.signalMinimumBaselineDays else { return nil }
        return (week, baseline)
    }

    private static func hasLoadData(_ load: [Day: Double], end: Day) -> Bool {
        let window = (0..<C.signalLoadWindowDays).map { end.adding(days: -$0) }
        let loaded = window.filter { (load[$0] ?? 0) > 0 }
        let beforeWeek = loaded.filter { $0 <= end.adding(days: -C.daysPerWeek) }
        return loaded.count >= C.signalLoadMinimumDays && beforeWeek.count >= C.signalLoadMinimumBaselineDays
    }

    private static func qualityStreakOffTarget(plan: TrainerPlan, history: TrainerHistory, start: Day, end: Day) -> Bool {
        let from = end.adding(days: 1 - C.signalPerformanceQualityWindowDays)
        let counted = plan.workouts
            .filter { ($0.kind == .threshold || $0.kind == .vo2max) && $0.day >= from && $0.day <= end }
            .sorted { $0.day < $1.day }
            .map { (day: $0.day, status: status(of: $0, history: history, today: end).status) }
            .filter { $0.status == .done || $0.status == .offTarget }
        let streak = counted.suffix(C.signalPerformanceQualityStreak)
        guard let latest = streak.last, latest.day >= start else { return false }
        return streak.count == C.signalPerformanceQualityStreak && streak.allSatisfy { $0.status == .offTarget }
    }

    private static func easyHeartRateDrift(history: TrainerHistory, start: Day, end: Day) -> Bool {
        let baselineStart = start.adding(days: -C.signalBaselineDays)
        let easy = history.runs.compactMap { run -> (day: Day, pace: Double, heartRate: Double)? in
            guard run.kind == .easy, run.meters > 0, let heartRate = run.averageHeartRate else { return nil }
            return (run.day, run.seconds / (run.meters / C.metersPerKilometer), heartRate)
        }
        let week = easy.filter { $0.day >= start && $0.day <= end }
        guard week.count >= C.signalPerformanceWeekRuns else { return false }
        let pace = mean(week.map(\.pace))
        let baseline = easy.filter {
            $0.day >= baselineStart && $0.day < start && abs($0.pace - pace) <= C.signalPerformancePaceBand
        }
        guard baseline.count >= C.signalPerformanceBaselineRuns else { return false }
        return mean(week.map(\.heartRate)) - mean(baseline.map(\.heartRate)) >= C.signalPerformanceHeartRate
    }

    private static func mean(_ values: [Double]) -> Double {
        values.reduce(0, +) / Double(values.count)
    }

    private static func deviation(_ values: [Double]) -> Double {
        let average = mean(values)
        return (values.map { ($0 - average) * ($0 - average) }.reduce(0, +) / Double(values.count)).squareRoot()
    }
}
