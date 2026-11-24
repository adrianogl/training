import Foundation
import TrainingCore

@MainActor final class MissingNightNotifier {
    private typealias C = MissingNightNotifierConstants

    private let scheduler: any NotificationScheduling
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(scheduler: any NotificationScheduling = NoticeInboxScheduler.standard, defaults: UserDefaults = AccountScope.current.defaults, calendar: Calendar = .current) {
        self.scheduler = scheduler
        self.defaults = defaults
        self.calendar = calendar
    }

    func update(hasNightData: Bool, now: Date) async {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        guard MorningNoticeSettings(defaults: defaults).enabled else {
            await scheduler.cancel(id: id(today))
            await scheduler.cancel(id: id(tomorrow))
            return
        }
        if hasNightData { await scheduler.cancel(id: id(today)) }
        if let todayAt = calendar.date(bySettingHour: C.hour, minute: 0, second: 0, of: today), now < todayAt, !hasNightData {
            await schedule(day: today, at: todayAt)
            return
        }
        guard let tomorrowAt = calendar.date(bySettingHour: C.hour, minute: 0, second: 0, of: tomorrow) else { return }
        await schedule(day: tomorrow, at: tomorrowAt)
    }

    private func schedule(day: Date, at date: Date) async {
        await scheduler.schedule(id: id(day), title: MissingNightNotifierText.title, text: MissingNightNotifierText.body, link: C.deepLink, at: date)
    }

    private func id(_ day: Date) -> String {
        C.idPrefix + Day.today(in: calendar.timeZone, now: day).iso
    }
}
