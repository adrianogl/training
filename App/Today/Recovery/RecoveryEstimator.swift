import Foundation
import GarminAPI
import TrainingCore

enum RecoveryEstimator {
    private typealias C = RecoveryConstants

    static func hours(aerobic: Double?, anaerobic: Double?, readiness: Int?) -> Int {
        var hours = C.baseHours.last { (aerobic ?? 0) >= $0.effect }?.hours ?? C.baseHours[0].hours
        if (anaerobic ?? 0) >= C.anaerobicHeavy { hours += C.anaerobicExtraHours }
        if let readiness {
            if readiness < C.lowReadiness { hours += C.lowReadinessExtraHours }
            if readiness >= C.goodReadiness { hours -= C.goodReadinessSavedHours }
        }
        return Int(hours)
    }

    static func estimate(run: RecoveryRun, readiness: Int?, planned: [PlannedWorkout], now: Date, calendar: Calendar = .current) -> RecoveryEstimate {
        let hours = hours(aerobic: run.aerobicEffect, anaerobic: run.anaerobicEffect, readiness: readiness)
        let readyAt = run.end.addingTimeInterval(Double(hours) * 3_600)
        let elapsed = now.timeIntervalSince(run.end)
        let progress = min(max(elapsed / (Double(hours) * 3_600), 0), 1)
        let next = planned
            .compactMap { plan -> (PlannedWorkout, Date)? in
                guard let day = Day(iso: plan.day),
                      let start = calendar.date(bySettingHour: run.typicalHour, minute: 0, second: 0, of: day.chartDate),
                      start > run.end else { return nil }
                return (plan, start)
            }
            .min { $0.1 < $1.1 }
            .map { plan, start in
                let gap = Int((start.timeIntervalSince(run.end) / 3_600).rounded())
                return RecoveryNext(title: plan.title, start: start, gapHours: gap, enough: gap >= hours)
            }
        return RecoveryEstimate(title: run.title, hours: hours, readyAt: readyAt, progress: progress, next: next)
    }

    static func typicalHour(_ starts: [Date], calendar: Calendar = .current) -> Int {
        let hours = starts.map { calendar.component(.hour, from: $0) }.sorted()
        guard !hours.isEmpty else { return C.defaultHour }
        return hours[hours.count / 2]
    }
}
