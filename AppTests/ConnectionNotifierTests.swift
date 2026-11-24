import Foundation
import Testing
@testable import trAIning

@MainActor @Suite struct ConnectionNotifierTests {
    private func notifier(_ scheduler: FakeNotificationScheduler, hour: Int = 10) -> ConnectionNotifier {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: hour))!
        return ConnectionNotifier(scheduler: scheduler, defaults: UserDefaults(suiteName: "connection-\(UUID())")!, calendar: calendar, now: { now })
    }

    @Test func notifiesOncePerEpisodeAndOpensSettings() async {
        let scheduler = FakeNotificationScheduler()
        let notifier = notifier(scheduler)
        await notifier.lost(.garmin)
        await notifier.lost(.garmin)
        #expect(await scheduler.delivered == ["connection-lost-garmin"])
        #expect(await scheduler.headers["connection-lost-garmin"]?.title == "Garmin desconectado")
        #expect(await scheduler.headers["connection-lost-garmin"]?.link == "training://ajustes")
        await notifier.restored(.garmin)
        await notifier.lost(.garmin)
        #expect(await scheduler.delivered.count == 2)
    }

    @Test func reconnectingRemovesDeliveredNoticeFromInbox() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 10))!
        let defaults = UserDefaults(suiteName: "connection-\(UUID())")!
        let inbox = NoticeInboxStore(defaults: defaults, calendar: calendar, now: { now })
        let scheduler = NoticeInboxScheduler(base: FakeNotificationScheduler(), inbox: inbox)
        let notifier = ConnectionNotifier(scheduler: scheduler, inbox: inbox, defaults: defaults, calendar: calendar, now: { now })
        await notifier.lost(.strava)
        #expect(inbox.entries().map(\.id) == ["connection-lost-strava"])
        await notifier.restored(.strava)
        #expect(inbox.entries().isEmpty)
    }

    @Test func waitsForMorningAtNight() async {
        let scheduler = FakeNotificationScheduler()
        await notifier(scheduler, hour: 23).lost(.strava)
        #expect(await scheduler.scheduled["connection-lost-strava"]?.at != nil)
        #expect(await scheduler.delivered.isEmpty)
    }
}
