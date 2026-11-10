import Foundation
import Insights
import Metrics
import Narrative
import Sync
import Testing
@testable import trAIning

actor FakeNotificationScheduler: NotificationScheduling {
    private(set) var scheduled: [String: (text: String, at: Date?)] = [:]
    private(set) var delivered: [String] = []

    func pending() async -> [String] {
        scheduled.filter { $0.value.at != nil }.map(\.key)
    }

    func schedule(id: String, text: String, at: Date?) async {
        scheduled[id] = (text, at)
        if at == nil { delivered.append(id) }
    }

    func cancel(id: String) async {
        scheduled[id] = nil
    }

    func markDelivered(id: String) {
        scheduled[id] = nil
        delivered.append(id)
    }
}

@MainActor
@Suite struct MorningNotifierTests {
    private let calendar = Calendar.current
    private let settings = MorningNoticeSettings(enabled: true, minimumMinutes: 6 * 60)

    private func date(hour: Int, minute: Int = 0, day: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func makeNotifier() -> (MorningNotifier, FakeNotificationScheduler) {
        let scheduler = FakeNotificationScheduler()
        let defaults = UserDefaults(suiteName: "MorningNotifierTests.\(UUID().uuidString)")!
        return (MorningNotifier(scheduler: scheduler, defaults: defaults, calendar: calendar), scheduler)
    }

    private func summary(score: Int = 74, components: [ReadinessComponent] = [.hrv, .sleep, .bodyBattery, .load]) -> TodaySummary {
        var summary = TodaySummary.empty
        summary.readiness = ReadinessBreakdown(
            score: score,
            normal: Double(score) - 6,
            factors: [
                ReadinessFactor(component: .hrv, todayScore: components.contains(.hrv) ? 80 : nil, normalScore: 70, points: components.contains(.hrv) ? 4 : nil, weight: 0.35),
                ReadinessFactor(component: .sleep, todayScore: components.contains(.sleep) ? 60 : nil, normalScore: 70, points: components.contains(.sleep) ? -2 : nil, weight: 0.25),
                ReadinessFactor(component: .bodyBattery, todayScore: 70, normalScore: 70, points: 0, weight: 0.2),
                ReadinessFactor(component: .load, todayScore: 70, normalScore: 70, points: 0, weight: 0.2),
            ]
        )
        summary.verdict = .hard
        return summary
    }

    @Test func schedulesAtMinimumHourWhenEarly() async {
        let (notifier, scheduler) = makeNotifier()

        await notifier.evaluate(summary: summary(), now: date(hour: 4), lastAppOpen: nil, settings: settings)

        let scheduled = await scheduler.scheduled
        #expect(scheduled.count == 1)
        #expect(scheduled.values.first?.at == date(hour: 6))
        #expect(scheduled.values.first?.text == morningNotificationText(summary().readiness!, verdict: .hard))
        #expect(await scheduler.delivered.isEmpty)
    }

    @Test func deliversImmediatelyAfterMinimumHour() async {
        let (notifier, scheduler) = makeNotifier()

        await notifier.evaluate(summary: summary(), now: date(hour: 7), lastAppOpen: nil, settings: settings)

        #expect(await scheduler.delivered.count == 1)
        #expect(await scheduler.pending().isEmpty)
    }

    @Test func replacesScheduledTextOnRecompute() async {
        let (notifier, scheduler) = makeNotifier()

        await notifier.evaluate(summary: summary(score: 74), now: date(hour: 4), lastAppOpen: nil, settings: settings)
        await notifier.evaluate(summary: summary(score: 58), now: date(hour: 5), lastAppOpen: nil, settings: settings)

        let scheduled = await scheduler.scheduled
        #expect(scheduled.count == 1)
        #expect(scheduled.values.first?.text == morningNotificationText(summary(score: 58).readiness!, verdict: .hard))
        #expect(scheduled.values.first?.at == date(hour: 6))
        #expect(await scheduler.delivered.isEmpty)
    }

    @Test func skipsWithoutHrvOrSleep() async {
        let (notifier, scheduler) = makeNotifier()

        await notifier.evaluate(summary: summary(components: [.sleep, .bodyBattery, .load]), now: date(hour: 7), lastAppOpen: nil, settings: settings)
        await notifier.evaluate(summary: summary(components: [.hrv, .bodyBattery, .load]), now: date(hour: 7), lastAppOpen: nil, settings: settings)
        await notifier.evaluate(summary: .empty, now: date(hour: 7), lastAppOpen: nil, settings: settings)
        await notifier.evaluate(summary: summary(), now: date(hour: 7), lastAppOpen: nil, settings: MorningNoticeSettings(enabled: false, minimumMinutes: 6 * 60))

        #expect(await scheduler.scheduled.isEmpty)
        #expect(await scheduler.delivered.isEmpty)
    }

    @Test func skipsWhenAlreadyNotifiedOrAppOpened() async {
        let (notifier, scheduler) = makeNotifier()
        await notifier.evaluate(summary: summary(), now: date(hour: 7), lastAppOpen: nil, settings: settings)
        await notifier.evaluate(summary: summary(score: 60), now: date(hour: 9), lastAppOpen: nil, settings: settings)
        #expect(await scheduler.delivered.count == 1)

        let (opened, openedScheduler) = makeNotifier()
        await opened.evaluate(summary: summary(), now: date(hour: 4), lastAppOpen: nil, settings: settings)
        await openedScheduler.markDelivered(id: openedScheduler.scheduled.keys.first!)
        await opened.evaluate(summary: summary(score: 60), now: date(hour: 7), lastAppOpen: nil, settings: settings)
        #expect(await openedScheduler.delivered.count == 1)

        let (afterOpen, afterOpenScheduler) = makeNotifier()
        await afterOpen.evaluate(summary: summary(), now: date(hour: 4), lastAppOpen: nil, settings: settings)
        await afterOpenScheduler.cancel(id: afterOpenScheduler.scheduled.keys.first!)
        await afterOpen.evaluate(summary: summary(), now: date(hour: 7), lastAppOpen: date(hour: 5), settings: settings)
        #expect(await afterOpenScheduler.scheduled.isEmpty)
        #expect(await afterOpenScheduler.delivered.isEmpty)
    }

    @Test func appOpenCancelsScheduled() async {
        let (notifier, scheduler) = makeNotifier()
        await notifier.evaluate(summary: summary(), now: date(hour: 4), lastAppOpen: nil, settings: settings)

        await notifier.appOpened(now: date(hour: 5))
        await notifier.evaluate(summary: summary(score: 60), now: date(hour: 5, minute: 30), lastAppOpen: notifier.lastAppOpen, settings: settings)

        #expect(notifier.lastAppOpen == date(hour: 5))
        #expect(await scheduler.scheduled.isEmpty)
        #expect(await scheduler.delivered.isEmpty)
    }

    @Test func foregroundSyncCancelsAndSuppressesNotice() async {
        let (notifier, scheduler) = makeNotifier()
        await notifier.evaluate(summary: summary(), now: date(hour: 4), lastAppOpen: nil, settings: settings)
        #expect(await scheduler.pending().count == 1)

        await notifier.foregroundSyncFinished(summary: summary(), now: date(hour: 4, minute: 30))

        #expect(await scheduler.scheduled.isEmpty)
        #expect(await scheduler.delivered.isEmpty)
    }

    @Test func openingSyncThatFirstCalculatesReadinessNeverNotifies() async {
        let (notifier, scheduler) = makeNotifier()
        await notifier.appOpened(now: date(hour: 5))
        await notifier.foregroundSyncFinished(summary: summary(), now: date(hour: 5, minute: 1))

        await notifier.evaluate(summary: summary(score: 60), now: date(hour: 5, minute: 30), lastAppOpen: notifier.lastAppOpen, settings: settings)
        await notifier.evaluate(summary: summary(score: 60), now: date(hour: 7), lastAppOpen: notifier.lastAppOpen, settings: settings)

        #expect(await scheduler.scheduled.isEmpty)
        #expect(await scheduler.delivered.isEmpty)
    }

    @Test func backgroundEngineUsesBackgroundMode() {
        let background = SyncEngineConfiguration(trigger: .background)
        #expect(background.mode == .background)
        #expect(background.waitsOnRateLimit == false)

        let launch = SyncEngineConfiguration(trigger: .launch)
        #expect(launch.mode == .foreground)
        #expect(launch.waitsOnRateLimit)
        #expect(SyncEngineConfiguration(trigger: .settings).mode == .foreground)
    }
}
