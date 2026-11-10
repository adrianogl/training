import Foundation
import Insights
import Metrics
import Narrative
import TrainingCore

@MainActor final class MorningNotifier {
    private typealias C = BackgroundConstants

    private let scheduler: any NotificationScheduling
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(scheduler: any NotificationScheduling = UserNotificationScheduler(), defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.scheduler = scheduler
        self.defaults = defaults
        self.calendar = calendar
    }

    var lastAppOpen: Date? { defaults.object(forKey: C.lastAppOpenDefaultsKey) as? Date }

    var settings: MorningNoticeSettings { MorningNoticeSettings(defaults: defaults) }

    func appOpened(now: Date) async {
        defaults.set(now, forKey: C.lastAppOpenDefaultsKey)
        await scheduler.cancel(id: notificationId(day: dayKey(now)))
    }

    func foregroundSyncFinished(summary: TodaySummary, now: Date) async {
        let day = dayKey(now)
        await scheduler.cancel(id: notificationId(day: day))
        guard Self.hasNightData(summary) else { return }
        _ = readyTime(day: day, now: now)
        defaults.set(now, forKey: C.lastAppOpenDefaultsKey)
    }

    func evaluate(summary: TodaySummary, now: Date, lastAppOpen: Date?, settings: MorningNoticeSettings) async {
        guard settings.enabled,
              let breakdown = summary.readiness,
              let verdict = summary.verdict,
              Self.hasNightData(summary)
        else { return }
        let day = dayKey(now)
        let readyAt = readyTime(day: day, now: now)
        if let lastAppOpen, dayKey(lastAppOpen) == day, lastAppOpen >= readyAt { return }
        let id = notificationId(day: day)
        if defaults.string(forKey: C.notifiedDayDefaultsKey) == day, await scheduler.pending().contains(id) == false { return }
        let minimum = calendar.date(byAdding: .minute, value: settings.minimumMinutes, to: calendar.startOfDay(for: now)) ?? now
        await scheduler.schedule(id: id, text: morningNotificationText(breakdown, verdict: verdict), at: now < minimum ? minimum : nil)
        defaults.set(day, forKey: C.notifiedDayDefaultsKey)
    }

    nonisolated static func hasNightData(_ summary: TodaySummary) -> Bool {
        guard let breakdown = summary.readiness else { return false }
        let present = Set(breakdown.factors.filter { $0.todayScore != nil }.map(\.component))
        return present.contains(.hrv) && present.contains(.sleep)
    }

    private func readyTime(day: String, now: Date) -> Date {
        if defaults.string(forKey: C.readyDayDefaultsKey) == day, let stored = defaults.object(forKey: C.readyAtDefaultsKey) as? Date {
            return stored
        }
        defaults.set(day, forKey: C.readyDayDefaultsKey)
        defaults.set(now, forKey: C.readyAtDefaultsKey)
        return now
    }

    private func dayKey(_ date: Date) -> String {
        Day.today(in: calendar.timeZone, now: date).iso
    }

    private func notificationId(day: String) -> String {
        C.notificationIdPrefix + day
    }
}

extension MorningNoticeSettings {
    init(defaults: UserDefaults) {
        self.init(
            enabled: defaults.object(forKey: BackgroundConstants.noticeEnabledDefaultsKey) as? Bool ?? BackgroundConstants.defaultNoticeEnabled,
            minimumMinutes: defaults.object(forKey: BackgroundConstants.noticeMinimumMinutesDefaultsKey) as? Int ?? BackgroundConstants.defaultMinimumMinutes
        )
    }
}
