import Foundation

struct NoticeInboxStore: Sendable {
    private typealias C = NoticeInboxConstants

    private static let lock = NSLock()

    nonisolated(unsafe) private let fixedDefaults: UserDefaults?
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    init(defaults: UserDefaults? = nil, calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { .now }) {
        self.fixedDefaults = defaults
        self.calendar = calendar
        self.now = now
    }

    private var defaults: UserDefaults { fixedDefaults ?? AccountScope.current.defaults }

    func record(id: String, title: String?, text: String, link: String, at date: Date?) {
        record(NoticeItem(id: id, title: title, text: text, link: link, deliverAt: date ?? now()))
    }

    func recordDaily(id: String, title: String, text: String, link: String, hour: Int) {
        let current = now()
        let first = calendar.nextDate(after: current, matching: DateComponents(hour: hour, minute: 0), matchingPolicy: .nextTime) ?? current
        record(NoticeItem(id: id, title: title, text: text, link: link, deliverAt: first, dailyHour: hour))
    }

    func record(_ item: NoticeItem) {
        mutate { items, current in
            guard let index = items.firstIndex(where: { $0.id == item.id }) else {
                items.append(item)
                return
            }
            let existing = items[index]
            var updated = item
            updated.readAt = existing.readAt
            if existing.dailyHour != nil, item.dailyHour == existing.dailyHour {
                updated.deliverAt = min(existing.deliverAt, item.deliverAt)
            } else if existing.dailyHour == nil, item.dailyHour == nil, existing.deliverAt <= current, item.deliverAt > current {
                var archived = existing
                archived.id = existing.id + C.archiveSeparator + String(Int(existing.deliverAt.timeIntervalSince1970))
                items.append(archived)
                updated.readAt = nil
            }
            items[index] = updated
        }
    }

    func remove(id: String) {
        mutate { items, _ in items.removeAll { $0.id == id } }
    }

    func removePending(id: String) {
        mutate { items, current in items.removeAll { $0.id == id && ($0.dailyHour != nil || $0.deliverAt > current) } }
    }

    func markRead(id: String) {
        mutate { items, current in
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items[index].readAt = current
        }
    }

    func markAllRead() {
        mutate { items, current in
            for index in items.indices where items[index].deliverAt <= current {
                items[index].readAt = current
            }
        }
    }

    func entries() -> [NoticeEntry] {
        let current = now()
        return load()
            .compactMap { item -> NoticeEntry? in
                guard let delivered = deliveredAt(item, now: current), delivered >= cutoff(current) else { return nil }
                return NoticeEntry(
                    id: item.id, title: item.title, text: item.text, link: item.link, deliveredAt: delivered,
                    isRead: item.readAt.map { $0 >= delivered } ?? false
                )
            }
            .sorted { $0.deliveredAt > $1.deliveredAt }
    }

    func unreadCount() -> Int {
        entries().filter { !$0.isRead }.count
    }

    func prune() {
        mutate { _, _ in }
    }

    private func deliveredAt(_ item: NoticeItem, now current: Date) -> Date? {
        guard item.deliverAt <= current else { return nil }
        guard let hour = item.dailyHour, let today = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: current) else {
            return item.deliverAt
        }
        let latest = today <= current ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        return max(latest, item.deliverAt)
    }

    private func cutoff(_ current: Date) -> Date {
        calendar.date(byAdding: .day, value: -C.retentionDays, to: current) ?? current
    }

    private func load() -> [NoticeItem] {
        guard let data = defaults.data(forKey: C.defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([NoticeItem].self, from: data)) ?? []
    }

    private func mutate(_ change: (inout [NoticeItem], Date) -> Void) {
        let current = now()
        Self.lock.withLock {
            var items = load()
            change(&items, current)
            let limit = cutoff(current)
            items.removeAll { item in deliveredAt(item, now: current).map { $0 < limit } ?? false }
            defaults.set(try? JSONEncoder().encode(items), forKey: C.defaultsKey)
        }
        NotificationCenter.default.post(name: C.changedNotification, object: nil)
    }
}
