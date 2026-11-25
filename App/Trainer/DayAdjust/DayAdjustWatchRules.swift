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

    static func retimed(_ entries: DayAdjustEntries, forecast: [HourlyWeather], hour: Int, now: Date) -> DayAdjustEntries {
        candidate(
            day: entries.day, score: entries.score, forecast: forecast, hour: hour, origin: .now,
            hotSessions: entries.hotSessions, heavyLegs: entries.heavyLegs, now: now
        )
    }

    static func seconds(_ result: TrainerDayAdjustResult) -> Int {
        guard case let .adjusted(change) = result else { return 0 }
        return change.seconds
    }

    static func laterOptions(_ watch: DayAdjustWatch, forecast: [HourlyWeather], currentHour: Int, now: Date) -> [DayAdjustHourOption] {
        let C = DayAdjustWatchConstants.self
        let options = forecast.map(\.hour).filter { $0 > currentHour && $0 <= C.lastStartHour }.map { hour in
            let entries = retimed(watch.entries, forecast: forecast, hour: hour, now: now)
            let result = TrainerDayAdjust.adjust(watch.workout, entries: entries)
            let workout = if case let .adjusted(change) = result { change.workout } else { watch.workout }
            return DayAdjustHourOption(hour: hour, entries: entries, result: result, seconds: seconds(result), paceLow: workout.paceLow)
        }
        let pinned = options.filter { $0.hour == watch.entries.hour }
        let rest = options.filter { $0.hour != watch.entries.hour }.sorted { ($0.seconds, $0.hour) < ($1.seconds, $1.hour) }
        return Array((pinned + rest).prefix(C.laterOptionsCount)).sorted { $0.hour < $1.hour }
    }

    static func matchesWatch(_ option: DayAdjustHourOption, watch: DayAdjustWatch) -> Bool {
        option.hour == watch.entries.hour && !TrainerDayAdjust.differs(watch.result, option.result)
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
