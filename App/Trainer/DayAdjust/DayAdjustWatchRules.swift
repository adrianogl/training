import Foundation
import Insights
import Storage
import TrainingCore

enum DayAdjustWatchRules {
    static func candidate(
        day: Day, score: Int?, forecast: [HourlyWeather], hour: Int, origin: DayAdjustOrigin, hotSessions: Int, heavyLegs: Bool, now: Date
    ) -> DayAdjustEntries {
        let weather = DayAdjust.closestIndex(to: hour, in: forecast.map(\.hour)).map { forecast[$0] }
        return DayAdjustEntries(
            day: day, hour: hour, origin: origin, score: score, temperature: weather?.temperature, dewPoint: weather?.dewPoint,
            radiation: weather?.radiation, hotSessions: hotSessions, heavyLegs: heavyLegs, computedAt: now
        )
    }

    static func keeps(existing: DayAdjustEntries?, candidate: DayAdjustEntries, workout: TrainerWorkout) -> Bool {
        guard let existing, existing.day == candidate.day else { return false }
        if existing.origin == .now { return true }
        return !TrainerDayAdjust.differs(
            TrainerDayAdjust.adjust(workout, entries: existing), TrainerDayAdjust.adjust(workout, entries: candidate)
        )
    }

    static func effective(local: DayAdjustEntries?, record: DayAdjustEntries?, workout: TrainerWorkout) -> DayAdjustEntries? {
        guard let record, record.day == workout.day else { return local?.day == workout.day ? local : nil }
        guard let local, local.day == record.day, local.computedAt > record.computedAt else { return record }
        if local.origin == .now { return local }
        return keeps(existing: record, candidate: local, workout: workout) ? record : local
    }

    static func includedHeatByActivity(_ records: [ActivityRecord], heat: [Day: IncludedHeat]) -> [Int64: Double] {
        guard !heat.isEmpty else { return [:] }
        var result: [Int64: Double] = [:]
        var used: Set<Day> = []
        for record in records.filter({ ActivityTypeKey.isRun($0.typeKey) }).sorted(by: { $0.start < $1.start }) {
            let day = WorkoutAnalysisContext.day(record)
            guard !used.contains(day), let included = heat[day], let name = record.workoutName,
                  WorkoutTitle.comparisonKey(name) == WorkoutTitle.comparisonKey(included.title) else { continue }
            used.insert(day)
            if included.share > 0 { result[record.activityId] = included.share }
        }
        return result
    }

    static func entries(record: TrainerSentRecord?, item: TrainerSendItem?, planId: Int64) -> DayAdjustEntries? {
        guard let record, record.kind == .run, record.workoutId == planId else { return nil }
        if let stored = record.dayAdjust { return stored }
        guard let item, item.signature == record.signature else { return nil }
        return item.dayAdjust
    }

    static func showsNow(_ watch: DayAdjustWatch, now: DayAdjustEntries) -> Bool {
        guard now.hour != watch.entries.hour else { return false }
        return TrainerDayAdjust.differs(watch.result, TrainerDayAdjust.adjust(watch.workout, entries: now))
    }

    static func time(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: DayAdjustWatchConstants.timeFormat, parts.hour ?? 0, parts.minute ?? 0)
    }

    static func status(_ watch: DayAdjustWatch, calendar: Calendar = .current) -> String? {
        guard let sentAt = watch.sentAt else { return nil }
        return String(format: DayAdjustWatchConstants.watchSinceFormat, time(sentAt, calendar: calendar), watch.entries.hour)
    }

    static func sendCaption(_ item: TrainerSendItem, record: TrainerSentRecord?) -> String? {
        guard item.dayAdjust != nil, let record, record.signature != item.signature,
              record.signature == item.planSignature || record.dayAdjust != nil else { return nil }
        guard let seconds = item.dayAdjustSeconds else { return DayAdjustWatchConstants.sendCaptionPlain }
        return String(format: DayAdjustWatchConstants.sendCaptionFormat, seconds)
    }
}
