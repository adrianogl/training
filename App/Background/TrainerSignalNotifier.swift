import Foundation
import Insights

@MainActor final class TrainerSignalNotifier {
    private typealias C = TrainerSignalNotifierConstants

    private let scheduler: any NotificationScheduling
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    init(
        scheduler: any NotificationScheduling = UserNotificationScheduler(), defaults: UserDefaults = AccountScope.current.defaults,
        calendar: Calendar = .current, now: @escaping () -> Date = { .now }
    ) {
        self.scheduler = scheduler
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    func notify(_ versions: [TrainerVersion], plan: TrainerPlan) async {
        guard plan.endedOn == nil else { return }
        for version in versions {
            guard let text = TrainerText.signalReason(version) else { continue }
            let key = Self.key(version, plan: plan)
            var notified = defaults.stringArray(forKey: C.notifiedDefaultsKey) ?? []
            guard !notified.contains(key) else { continue }
            notified.append(key)
            defaults.set(Array(notified.suffix(C.notifiedLimit)), forKey: C.notifiedDefaultsKey)
            await scheduler.schedule(
                id: C.idPrefix + key, title: TrainerSignalNotifierText.title, text: text, link: C.deepLink, at: deliveryDate()
            )
        }
    }

    func deliveryDate() -> Date? {
        let current = now()
        let hour = calendar.component(.hour, from: current)
        guard hour >= C.quietStartHour || hour < C.quietEndHour else { return nil }
        let day = hour >= C.quietStartHour ? calendar.date(byAdding: .day, value: 1, to: current) ?? current : current
        return calendar.date(bySettingHour: C.quietEndHour, minute: 0, second: 0, of: day)
    }

    private static func key(_ version: TrainerVersion, plan: TrainerPlan) -> String {
        let created = Int(plan.versions.first?.createdAt.timeIntervalSince1970 ?? 0)
        return "\(created)-\(version.number)"
    }
}
