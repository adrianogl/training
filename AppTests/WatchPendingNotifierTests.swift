import Foundation
import Testing
import TrainingCore
@testable import trAIning

@MainActor @Suite struct WatchPendingNotifierTests {
    private let tomorrow = Day(iso: "2026-11-21")!
    private let id = "watch-pending-2026-11-21"

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: hour))!
    }

    private func inbox(hour: Int) -> NoticeInboxStore {
        let now = date(hour: hour)
        return NoticeInboxStore(defaults: UserDefaults(suiteName: "watch-pending-\(UUID())")!, calendar: calendar, now: { now })
    }

    private func notifier(_ scheduler: FakeNotificationScheduler, inbox: NoticeInboxStore, hour: Int) -> WatchPendingNotifier {
        let now = date(hour: hour)
        return WatchPendingNotifier(scheduler: scheduler, inbox: inbox, calendar: calendar, now: { now })
    }

    private func item(_ title: String, day: Day? = nil, kind: TrainerSendKind = .run, payload: String = "v1") -> TrainerSendItem {
        let day = day ?? tomorrow
        return TrainerSendItem(key: "\(kind.rawValue)|\(day.iso)|\(title)", day: day, kind: kind, title: title, payload: Data(payload.utf8))
    }

    private func record(_ item: TrainerSendItem, signature: String? = nil) -> [String: TrainerSentRecord] {
        [item.key: TrainerSentRecord(workoutId: 1, signature: signature ?? item.signature, day: item.day.iso, kind: item.kind)]
    }

    @Test func schedulesAtEightWithTheSendAction() async {
        let scheduler = FakeNotificationScheduler()
        let longRun = item("Longão 18 km")
        await notifier(scheduler, inbox: inbox(hour: 10), hour: 10).update(tomorrow: tomorrow, items: [longRun], records: [:], enabled: true)
        #expect(await scheduler.scheduled[id]?.at == date(hour: 20))
        #expect(await scheduler.scheduled[id]?.text == "Toque para enviar.")
        #expect(await scheduler.headers[id]?.title == "Longão 18 km de amanhã não está no Garmin")
        #expect(await scheduler.headers[id]?.link == "training://treinador/enviar")
        #expect(await scheduler.categories[id] == "watch-pending")
    }

    @Test func saysWhatChangedWhenTheWatchHasAnOldVersion() async {
        let scheduler = FakeNotificationScheduler()
        let longRun = item("Longão 18 km")
        await notifier(scheduler, inbox: inbox(hour: 10), hour: 10)
            .update(tomorrow: tomorrow, items: [longRun], records: record(longRun, signature: "old"), enabled: true)
        #expect(await scheduler.scheduled[id]?.text == "O plano mudou para Longão 18 km e o relógio ainda tem a versão anterior.")
    }

    @Test func countsSeveralPendingWorkoutsAndIgnoresOtherDays() async {
        let scheduler = FakeNotificationScheduler()
        let items = [item("Rodagem 8 km"), item("Pernas", kind: .strength), item("Limiar 9 km", day: tomorrow.adding(days: 1))]
        await notifier(scheduler, inbox: inbox(hour: 10), hour: 10).update(tomorrow: tomorrow, items: items, records: [:], enabled: true)
        #expect(await scheduler.headers[id]?.title == "2 treinos de amanhã não estão no Garmin")
        #expect(await scheduler.scheduled[id]?.text == "Toque para enviar.")
    }

    @Test func cancelsAndClearsTheListWhenEverythingIsOnTheWatch() async {
        let scheduler = FakeNotificationScheduler()
        let store = inbox(hour: 21)
        store.record(id: id, title: "Longão 18 km de amanhã não está no Garmin", text: "Toque para enviar.", link: DeepLinkConstants.trainerSend, at: date(hour: 20))
        let longRun = item("Longão 18 km")
        await notifier(scheduler, inbox: store, hour: 21).update(tomorrow: tomorrow, items: [longRun], records: record(longRun), enabled: true)
        #expect(await scheduler.scheduled[id] == nil)
        #expect(store.entries().isEmpty)
    }

    @Test func cancelsWithoutGarmin() async {
        let scheduler = FakeNotificationScheduler()
        let notifier = notifier(scheduler, inbox: inbox(hour: 10), hour: 10)
        await notifier.update(tomorrow: tomorrow, items: [item("Longão 18 km")], records: [:], enabled: true)
        await notifier.update(tomorrow: tomorrow, items: [item("Longão 18 km")], records: [:], enabled: false)
        #expect(await scheduler.scheduled.isEmpty)
    }

    @Test func doesNotScheduleAfterEightPm() async {
        let scheduler = FakeNotificationScheduler()
        await notifier(scheduler, inbox: inbox(hour: 20), hour: 20).update(tomorrow: tomorrow, items: [item("Longão 18 km")], records: [:], enabled: true)
        #expect(await scheduler.scheduled.isEmpty)
    }
}
