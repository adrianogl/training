import Foundation
import Synchronization
import Testing
@testable import trAIning

private final class NoticeClock: Sendable {
    private let value: Mutex<Date>

    init(_ date: Date) {
        value = Mutex(date)
    }

    var now: Date { value.withLock { $0 } }

    func set(_ date: Date) {
        value.withLock { $0 = date }
    }
}

@MainActor @Suite struct NoticeInboxTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func makeStore(at start: Date) -> (NoticeInboxStore, NoticeClock) {
        let clock = NoticeClock(start)
        let defaults = UserDefaults(suiteName: "NoticeInboxTests.\(UUID().uuidString)")!
        return (NoticeInboxStore(defaults: defaults, calendar: calendar, now: { clock.now }), clock)
    }

    @Test func recordsAndUpdatesTheSameId() {
        let (store, _) = makeStore(at: date(day: 24, hour: 9))
        store.record(id: "a", title: "Garmin desconectado", text: "Entre de novo", link: DeepLinkConstants.settings, at: nil)
        store.record(id: "a", title: "Garmin desconectado", text: "Entre de novo em Ajustes", link: DeepLinkConstants.settings, at: nil)
        let entries = store.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.text == "Entre de novo em Ajustes")
        #expect(entries.first?.link == DeepLinkConstants.settings)
        #expect(entries.first?.isRead == false)
    }

    @Test func hidesItemsBeforeTheirDeliveryTime() {
        let (store, clock) = makeStore(at: date(day: 24, hour: 23))
        store.record(id: "quiet", title: nil, text: "Semana leve", link: DeepLinkConstants.trainerChanges, at: date(day: 25, hour: 7))
        #expect(store.entries().isEmpty)
        #expect(store.unreadCount() == 0)
        clock.set(date(day: 25, hour: 7, minute: 1))
        #expect(store.entries().map(\.id) == ["quiet"])
        #expect(store.entries().first?.deliveredAt == date(day: 25, hour: 7))
    }

    @Test func countsAndMarksAsRead() {
        let (store, clock) = makeStore(at: date(day: 24, hour: 9))
        store.record(id: "a", title: "A", text: "a", link: DeepLinkConstants.today, at: nil)
        clock.set(date(day: 24, hour: 10))
        store.record(id: "b", title: "B", text: "b", link: DeepLinkConstants.today, at: nil)
        store.record(id: "later", title: "C", text: "c", link: DeepLinkConstants.today, at: date(day: 24, hour: 20))
        #expect(store.unreadCount() == 2)
        #expect(store.entries().map(\.id) == ["b", "a"])
        store.markRead(id: "a")
        #expect(store.unreadCount() == 1)
        store.markAllRead()
        #expect(store.unreadCount() == 0)
        clock.set(date(day: 24, hour: 20, minute: 5))
        #expect(store.unreadCount() == 1)
        #expect(store.entries().first { !$0.isRead }?.id == "later")
    }

    @Test func removesById() {
        let (store, _) = makeStore(at: date(day: 24, hour: 9))
        store.record(id: "a", title: "A", text: "a", link: DeepLinkConstants.today, at: nil)
        store.record(id: "b", title: "B", text: "b", link: DeepLinkConstants.today, at: nil)
        store.remove(id: "a")
        #expect(store.entries().map(\.id) == ["b"])
    }

    @Test func dropsItemsOlderThanThirtyDays() {
        let (store, clock) = makeStore(at: date(day: 1, hour: 9))
        store.record(id: "old", title: "A", text: "a", link: DeepLinkConstants.today, at: nil)
        clock.set(date(day: 20, hour: 9))
        store.record(id: "recent", title: "B", text: "b", link: DeepLinkConstants.today, at: nil)
        clock.set(calendar.date(byAdding: .day, value: 30, to: date(day: 1, hour: 10))!)
        #expect(store.entries().map(\.id) == ["recent"])
        store.prune()
        clock.set(date(day: 21, hour: 9))
        #expect(store.entries().map(\.id) == ["recent"])
    }

    @Test func keepsTheDeliveredCopyWhenTheSameIdIsScheduledAgain() {
        let (store, clock) = makeStore(at: date(day: 22, hour: 20))
        store.record(id: WeeklyReportConstants.notificationId, title: nil, text: "Semana 1", link: BackgroundConstants.readinessDeepLink, at: date(day: 22, hour: 20))
        clock.set(date(day: 23, hour: 9))
        store.record(id: WeeklyReportConstants.notificationId, title: nil, text: "Semana 2", link: BackgroundConstants.readinessDeepLink, at: date(day: 29, hour: 20))
        #expect(store.entries().map(\.text) == ["Semana 1"])
        clock.set(date(day: 29, hour: 21))
        #expect(store.entries().map(\.text) == ["Semana 2", "Semana 1"])
    }

    @Test func dailyNoticeIsOneItemAtTheLatestDelivery() {
        let (store, clock) = makeStore(at: date(day: 24, hour: 9))
        store.recordDaily(id: "update", title: "Versão nova", text: "1.55.0", link: DeepLinkConstants.today, hour: 8)
        #expect(store.entries().isEmpty)
        clock.set(date(day: 25, hour: 8, minute: 30))
        store.recordDaily(id: "update", title: "Versão nova", text: "1.55.0", link: DeepLinkConstants.today, hour: 8)
        #expect(store.entries().map(\.deliveredAt) == [date(day: 25, hour: 8)])
        store.markAllRead()
        clock.set(date(day: 27, hour: 9))
        let entries = store.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.deliveredAt == date(day: 27, hour: 8))
        #expect(entries.first?.isRead == false)
    }

    @Test func schedulerRecordsAndForwards() async {
        let (store, clock) = makeStore(at: date(day: 24, hour: 9))
        let base = FakeNotificationScheduler()
        let scheduler = NoticeInboxScheduler(base: base, inbox: store)
        await scheduler.schedule(id: "connection-garmin", title: "Garmin desconectado", text: "Entre de novo", link: DeepLinkConstants.settings, at: nil)
        clock.set(date(day: 24, hour: 9, minute: 5))
        await scheduler.schedule(id: "morning-readiness-2026-11-24", text: "Prontidão 74", at: nil)
        await scheduler.schedule(id: "race", title: "Véspera", text: "Amanhã", link: RaceNoticeConstants.link, at: date(day: 25, hour: 19))
        #expect(await base.delivered == ["connection-garmin", "morning-readiness-2026-11-24"])
        #expect(await base.pending() == ["race"])
        #expect(store.entries().map(\.id) == ["morning-readiness-2026-11-24", "connection-garmin"])
        #expect(store.entries().first?.link == BackgroundConstants.readinessDeepLink)
        clock.set(date(day: 25, hour: 19, minute: 1))
        #expect(store.entries().first?.id == "race")
    }

    @Test func schedulerCancelDropsOnlyWhatHasNotBeenDelivered() async {
        let (store, _) = makeStore(at: date(day: 24, hour: 9))
        let base = FakeNotificationScheduler()
        let scheduler = NoticeInboxScheduler(base: base, inbox: store)
        await scheduler.schedule(id: "morning", text: "Prontidão 74", at: nil)
        await scheduler.schedule(id: "race", title: "Véspera", text: "Amanhã", link: RaceNoticeConstants.link, at: date(day: 25, hour: 19))
        await scheduler.scheduleDaily(id: "update", title: "Versão nova", text: "1.55.0", link: DeepLinkConstants.today, hour: 8)
        await scheduler.cancel(id: "morning")
        await scheduler.cancel(id: "race")
        await scheduler.cancel(id: "update")
        #expect(await base.pending().isEmpty)
        #expect(await base.daily.isEmpty)
        #expect(store.entries().map(\.id) == ["morning"])
        store.markAllRead()
        await scheduler.schedule(id: "race", title: "Véspera", text: "Amanhã", link: RaceNoticeConstants.link, at: date(day: 25, hour: 19))
        #expect(store.unreadCount() == 0)
    }

    @Test func modelMarksAsReadWhenOpened() throws {
        let (store, clock) = makeStore(at: date(day: 24, hour: 9))
        store.record(id: "plan", title: "Plano atualizado", text: "Semana leve", link: DeepLinkConstants.trainerChanges, at: nil)
        store.record(id: "claude", title: "2 treinos de força", text: "Revise", link: DeepLinkConstants.trainerStrength, at: nil)
        let model = NoticeInboxModel(store: store)
        #expect(model.unreadCount == 2)
        model.open(try #require(model.entries.first { $0.id == "plan" }))
        #expect(model.unreadCount == 1)
        #expect(model.earlier.map(\.id) == ["plan"])
        model.markAllRead()
        #expect(model.fresh.isEmpty)
        clock.set(date(day: 24, hour: 10))
        store.record(id: "new", title: "Novo", text: "n", link: DeepLinkConstants.today, at: nil)
        model.reload()
        #expect(model.unreadCount == 1)
    }

    @Test func bellLabelCountsUnread() {
        #expect(NoticeInboxText.bellLabel(unread: 0) == "Avisos")
        #expect(NoticeInboxText.bellLabel(unread: 1) == "Avisos, 1 não lido")
        #expect(NoticeInboxText.bellLabel(unread: 3) == "Avisos, 3 não lidos")
    }
}
