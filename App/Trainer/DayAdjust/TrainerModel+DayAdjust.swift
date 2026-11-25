import Foundation
import GarminAPI
import Insights
import Storage
import TrainingCore

extension TrainerModel {
    var adjustsTodayRun: Bool {
        sendsToGarmin && TrainerSendStore(defaults: defaults).settings().runFromTrainer
    }

    var todayRun: TrainerWorkout? {
        guard plan?.endedOn == nil, let workout = plan?.workouts.first(where: { $0.day == currentDay }),
              !TrainerSendConstants.skippedKinds.contains(workout.kind) else { return nil }
        return workout
    }

    func sentRun(planId: Int64) -> TrainerWorkout? {
        guard adjustsTodayRun, let workout = todayRun,
              let record = TrainerSendStore(defaults: defaults).records()[TrainerSendConstants.runKeyPrefix + currentDay.iso],
              record.kind == .run, record.workoutId == planId else { return nil }
        return workout
    }

    func todayEntries(for workout: TrainerWorkout) -> DayAdjustEntries? {
        guard workout.day == currentDay, adjustsTodayRun else { return nil }
        return effectiveEntries(for: workout)
    }

    private func effectiveEntries(for workout: TrainerWorkout) -> DayAdjustEntries? {
        let record = TrainerSendStore(defaults: defaults).records()[TrainerSendConstants.runKeyPrefix + workout.day.iso]
        return DayAdjustWatchRules.effective(
            local: TrainerDayAdjustStore(defaults: defaults).load(day: workout.day), record: record?.dayAdjust, workout: workout
        )
    }

    func dayAdjusted(_ workout: TrainerWorkout) -> TrainerDayAdjustment? {
        guard let entries = todayEntries(for: workout),
              case let .adjusted(change) = TrainerDayAdjust.adjust(workout, entries: entries) else { return nil }
        return change
    }

    func runSendItem(_ workout: TrainerWorkout) -> TrainerSendItem? {
        TrainerSendBuilder.runItem(
            workout, entries: todayEntries(for: workout), thresholdHeartRate: thresholdHeartRate, maxHeartRate: maxHeartRate
        )
    }

    func watchDayAdjust(planId: Int64) -> DayAdjustWatch? {
        guard let workout = todayRun else { return nil }
        let entry = TrainerSendStore(defaults: defaults).ledger().entries[TrainerSendConstants.runKeyPrefix + currentDay.iso]
        guard let entries = DayAdjustWatchRules.entries(record: entry?.record, item: runSendItem(workout), planId: planId) else { return nil }
        return DayAdjustWatch(
            entries: entries, workout: workout, result: TrainerDayAdjust.adjust(workout, entries: entries), sentAt: entry?.updatedAt
        )
    }

    static func dayScore(_ summary: TodaySummary, day: Day, defaults: UserDefaults) -> Int? {
        guard !summary.readinessFromYesterday else { return nil }
        return summary.readiness?.score ?? GarminReadinessCache.cached(day: day, defaults: defaults)?.score
    }

    func dayAdjustCandidate(
        workout: TrainerWorkout, score: Int?, forecast: [HourlyWeather], hour: Int?, origin: DayAdjustOrigin, now: Date = .now
    ) -> DayAdjustEntries {
        let context = container.mainContext
        let recent = TodayModel.recentRuns(context: context)
        let day = workout.day
        let heavyLegs = StrengthModel.legDay(in: context, planned: plannedLegs(on: day.adding(days: -1)), before: day) != nil
        let usual = UsualHour.hour(for: now, long: workout.kind == .long, runs: DayAdjustText.usualRuns(recent), now: now, calendar: .current)
        return DayAdjustWatchRules.candidate(
            day: day, score: score, forecast: forecast, hour: hour ?? usual, origin: origin,
            hotSessions: ActivityRecord.hotSessions(before: now, among: recent), heavyLegs: heavyLegs, now: now
        )
    }

    @discardableResult
    func refreshDayAdjust(summary: TodaySummary, now: Date = .now) async -> Bool {
        let day = currentDay
        guard adjustsTodayRun, let workout = todayRun else { return false }
        let recent = TodayModel.recentRuns(context: container.mainContext)
        guard !recent.contains(where: { Day.today(now: $0.start) == day }) else { return false }
        let store = TrainerDayAdjustStore(defaults: defaults)
        let score = Self.dayScore(summary, day: day, defaults: defaults)
        if readinessSuggestion(score: score, factor: Self.lowestFactor(summary.readiness)) != nil {
            return store.clear(day: day)
        }
        let existing = effectiveEntries(for: workout)
        if let existing, store.load(day: day) != existing { store.save(existing) }
        if existing?.origin == .now { return false }
        let forecast = await forecast(for: day)
        guard !Task.isCancelled else { return false }
        if forecast.isEmpty, existing != nil { return false }
        let candidate = dayAdjustCandidate(workout: workout, score: score, forecast: forecast, hour: nil, origin: .usual, now: now)
        guard !DayAdjustWatchRules.keeps(existing: existing, candidate: candidate, workout: workout) else { return false }
        store.save(candidate)
        return true
    }

    func sendNowDayAdjust(_ entries: DayAdjustEntries, client: GarminAccountClient?) async -> TrainerSendResult? {
        guard let client, let workout = todayRun, workout.day == entries.day else { return nil }
        let store = TrainerDayAdjustStore(defaults: defaults)
        let previous = store.load(day: entries.day)
        store.save(entries)
        guard let item = runSendItem(workout) else { return nil }
        let result = await sendToGarmin([item], stale: [], client: client)
        if let result, result.sent == 0, result.failed > 0 {
            if let previous { store.save(previous) } else { store.clear(day: entries.day) }
        }
        return result
    }
}
