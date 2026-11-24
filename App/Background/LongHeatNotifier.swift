import Foundation
import TrainingCore

@MainActor final class LongHeatNotifier {
    private typealias C = LongHeatNotifierConstants

    private let scheduler: any NotificationScheduling
    private let calendar: Calendar
    private let now: () -> Date

    init(scheduler: any NotificationScheduling = NoticeInboxScheduler.standard, calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.scheduler = scheduler
        self.calendar = calendar
        self.now = now
    }

    var deliveryDate: Date? {
        let current = now()
        guard let date = calendar.date(bySettingHour: C.hour, minute: 0, second: 0, of: current), current < date else { return nil }
        return date
    }

    func update(longDay day: Day, heat: TrainerHeatDay?) async {
        guard let date = deliveryDate else { return }
        let id = C.idPrefix + day.iso
        guard let heat, let usual = heat.hour(heat.usualHour), usual.heat.paceOffset >= RunWeatherConstants.minimumHeatSeconds,
              let text = LongHeatNotifierText.body(heat) else {
            await scheduler.cancel(id: id)
            return
        }
        await scheduler.schedule(id: id, title: LongHeatNotifierText.title, text: text, link: DeepLink.trainerDayURL(day.iso), at: date)
    }
}
