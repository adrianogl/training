import Foundation
import TrainingCore

@MainActor enum StrengthRecordNotifier {
    private typealias C = StrengthConstants

    static func notify(_ series: [StrengthLoadSeries], today: Day, defaults: UserDefaults = AccountScope.current.defaults, scheduler: any NotificationScheduling = NoticeInboxScheduler.standard) async {
        var notified = Set(defaults.stringArray(forKey: C.recordNotifiedKey) ?? [])
        for item in series where item.isNewRecord {
            guard let last = item.points.last, last.day >= today.adding(days: -C.recordNoticeDays) else { continue }
            let key = "\(item.key)|\(last.day.iso)"
            guard !notified.contains(key) else { continue }
            notified.insert(key)
            await scheduler.schedule(id: "strength-record-" + key, title: StrengthText.recordTitle(item.name), text: StrengthText.recordText(item, today: today), link: C.recordLink, at: nil)
        }
        defaults.set(Array(notified), forKey: C.recordNotifiedKey)
    }
}
