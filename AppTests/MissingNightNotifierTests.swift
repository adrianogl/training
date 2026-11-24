import Foundation
import Testing
@testable import trAIning

@MainActor @Suite struct MissingNightNotifierTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(day: Int = 20, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func make(enabled: Bool = true) -> (MissingNightNotifier, FakeNotificationScheduler, UserDefaults) {
        let scheduler = FakeNotificationScheduler()
        let defaults = UserDefaults(suiteName: "missing-night-\(UUID())")!
        defaults.set(enabled, forKey: BackgroundConstants.noticeEnabledDefaultsKey)
        return (MissingNightNotifier(scheduler: scheduler, defaults: defaults, calendar: calendar), scheduler, defaults)
    }

    @Test func schedulesTodayAtTenWithoutNightData() async {
        let (notifier, scheduler, _) = make()
        await notifier.update(hasNightData: false, now: date(hour: 4))
        let id = "missing-night-2026-11-20"
        #expect(await scheduler.scheduled[id]?.at == date(hour: 10))
        #expect(await scheduler.headers[id]?.title == "A noite não chegou")
        #expect(await scheduler.headers[id]?.link == "training://hoje/prontidao")
        #expect(await scheduler.scheduled[id]?.text == "O relógio ainda não mandou HRV e sono, por isso a prontidão não saiu. Abra o app ou o Garmin Connect para sincronizar.")
    }

    @Test func nightDataCancelsTodayAndArmsTomorrow() async {
        let (notifier, scheduler, _) = make()
        await notifier.update(hasNightData: false, now: date(hour: 4))
        await notifier.update(hasNightData: true, now: date(hour: 6))
        #expect(await scheduler.scheduled["missing-night-2026-11-20"] == nil)
        #expect(await scheduler.scheduled["missing-night-2026-11-21"]?.at == date(day: 21, hour: 10))
    }

    @Test func afterTenArmsTomorrow() async {
        let (notifier, scheduler, _) = make()
        await notifier.update(hasNightData: false, now: date(hour: 11))
        #expect(await scheduler.scheduled.keys.sorted() == ["missing-night-2026-11-21"])
    }

    @Test func turningTheReadinessNoticeOffCancelsBoth() async {
        let (notifier, scheduler, defaults) = make()
        await notifier.update(hasNightData: false, now: date(hour: 4))
        await notifier.update(hasNightData: true, now: date(hour: 5))
        defaults.set(false, forKey: BackgroundConstants.noticeEnabledDefaultsKey)
        await notifier.update(hasNightData: false, now: date(hour: 5))
        #expect(await scheduler.scheduled.isEmpty)
    }
}
