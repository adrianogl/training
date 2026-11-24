import Foundation
import Insights
import TrainingCore

@MainActor final class TrainerChangeNotifier {
    private typealias C = TrainerChangeNotifierConstants
    private typealias T = TrainerChangeNotifierText

    private let scheduler: any NotificationScheduling
    private let inbox: NoticeInboxStore
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    init(
        scheduler: any NotificationScheduling = NoticeInboxScheduler.standard, inbox: NoticeInboxStore = NoticeInboxStore(),
        defaults: UserDefaults = AccountScope.current.defaults, calendar: Calendar = .current, now: @escaping () -> Date = { .now }
    ) {
        self.scheduler = scheduler
        self.inbox = inbox
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    func notify(before: [TrainerWorkout], after: [TrainerWorkout], today: Day, done: Set<Day>, watch: (TrainerWorkout) -> TrainerChangeWatch) async {
        let current = now()
        let hour = calendar.component(.hour, from: current)
        let quietDelivery = QuietHours.deliveryDate(now: current, calendar: calendar)
        let morningDay = hour >= QuietHours.startHour ? today.adding(days: 1) : today
        let pending = Set(await scheduler.pending())
        for offset in 0...C.daysAhead {
            let day = today.adding(days: offset)
            guard !done.contains(day) else { continue }
            guard let workout = after.first(where: { $0.day == day }) else {
                await cancel(day, pending: pending)
                continue
            }
            let previous = before.first { $0.day == day }
            guard Self.changed(previous, workout) else { continue }
            guard let delivery = quietDelivery else {
                forget(day)
                await schedule(workout, isToday: day == today, watch: watch(workout), at: nil)
                continue
            }
            if hour >= QuietHours.startHour, day == today { continue }
            let waiting = pending.contains(C.idPrefix + day.iso) || defaults.string(forKey: C.morningDayKey) == day.iso
            let reference = waiting ? pendingChanges()[day.iso]?.before ?? previous : previous
            if day == morningDay, MorningNoticeSettings(defaults: defaults).enabled,
               defaults.string(forKey: BackgroundConstants.notifiedDayDefaultsKey) != day.iso {
                defaults.set(day.iso, forKey: C.morningDayKey)
                defaults.set(T.morningSummary(workout), forKey: C.morningSummaryKey)
                remember(day, TrainerChangePending(before: reference, at: nil))
                continue
            }
            remember(day, TrainerChangePending(before: reference, at: delivery))
            await schedule(workout, isToday: day == deliveryDay(delivery), watch: watch(workout), at: delivery)
        }
    }

    func refresh(_ workouts: [TrainerWorkout], today: Day, watch: (TrainerWorkout) -> TrainerChangeWatch) async {
        let pending = Set(await scheduler.pending())
        var records = pendingChanges()
        records = records.filter { Day(iso: $0.key).map { $0 >= today } ?? false }
        savePending(records)
        for offset in 0...C.daysAhead {
            let day = today.adding(days: offset)
            guard let workout = workouts.first(where: { $0.day == day }) else {
                await cancel(day, pending: pending)
                continue
            }
            let record = records[day.iso]
            if let before = record?.before, !Self.changed(before, workout) {
                await cancel(day, pending: pending)
                continue
            }
            if defaults.string(forKey: C.morningDayKey) == day.iso {
                defaults.set(T.morningSummary(workout), forKey: C.morningSummaryKey)
            }
            guard pending.contains(C.idPrefix + day.iso), let delivery = record?.at ?? QuietHours.deliveryDate(now: now(), calendar: calendar) else { continue }
            await schedule(workout, isToday: day == deliveryDay(delivery), watch: watch(workout), at: delivery)
        }
    }

    func recordLaterChanges(_ versions: [TrainerVersion], plan: TrainerPlan, today: Day) {
        let last = today.adding(days: C.daysAhead)
        let created = Int(plan.versions.first?.createdAt.timeIntervalSince1970 ?? 0)
        for version in versions where TrainerText.signalReason(version) == nil && Self.changesAfter(last, version: version, plan: plan) {
            inbox.record(id: "\(C.planIdPrefix)\(created)-\(version.number)", title: T.planTitle, text: version.summary, link: C.deepLink, at: nil)
        }
    }

    static func changesAfter(_ last: Day, version: TrainerVersion, plan: TrainerPlan) -> Bool {
        version.changes.contains { change in
            guard change.kind != .unchanged else { return false }
            if let day = change.day { return day > last }
            guard let index = change.weekIndex, let week = plan.weeks.first(where: { $0.index == index }) else { return false }
            return week.start.adding(days: TrainerConstants.weekdayCount - 1) > last
        }
    }

    static func morningLine(defaults: UserDefaults, day: String, run: String?) -> String? {
        guard defaults.string(forKey: C.morningDayKey) == day, let summary = defaults.string(forKey: C.morningSummaryKey) else { return run }
        return T.morningLine(run: run, summary: summary)
    }

    static func changed(_ old: TrainerWorkout?, _ new: TrainerWorkout) -> Bool {
        guard let old else { return true }
        return old.kind != new.kind || old.title != new.title || old.totalMeters != new.totalMeters || old.steps != new.steps
            || old.paceLow != new.paceLow || old.paceHigh != new.paceHigh
    }

    private func cancel(_ day: Day, pending: Set<String>) async {
        if pending.contains(C.idPrefix + day.iso) { await scheduler.cancel(id: C.idPrefix + day.iso) }
        forget(day)
        guard defaults.string(forKey: C.morningDayKey) == day.iso else { return }
        defaults.removeObject(forKey: C.morningDayKey)
        defaults.removeObject(forKey: C.morningSummaryKey)
    }

    private func deliveryDay(_ delivery: Date) -> Day {
        Day.today(in: calendar.timeZone, now: delivery)
    }

    private func pendingChanges() -> [String: TrainerChangePending] {
        guard let data = defaults.data(forKey: C.pendingKey) else { return [:] }
        return (try? JSONDecoder().decode([String: TrainerChangePending].self, from: data)) ?? [:]
    }

    private func savePending(_ records: [String: TrainerChangePending]) {
        defaults.set(try? JSONEncoder().encode(records), forKey: C.pendingKey)
    }

    private func remember(_ day: Day, _ record: TrainerChangePending) {
        var records = pendingChanges()
        records[day.iso] = record
        savePending(records)
    }

    private func forget(_ day: Day) {
        var records = pendingChanges()
        guard records.removeValue(forKey: day.iso) != nil else { return }
        savePending(records)
    }

    private func schedule(_ workout: TrainerWorkout, isToday: Bool, watch: TrainerChangeWatch, at date: Date?) async {
        await scheduler.schedule(
            id: C.idPrefix + workout.day.iso, title: T.title(isToday: isToday), text: T.body(workout, watch: watch), link: C.deepLink, at: date
        )
    }
}
