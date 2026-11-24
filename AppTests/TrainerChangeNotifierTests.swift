import Foundation
import Insights
import Testing
import TrainingCore
@testable import trAIning

@MainActor @Suite struct TrainerChangeNotifierTests {
    private let today = Day(iso: "2026-11-20")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(day: Int = 20, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func notifier(_ scheduler: FakeNotificationScheduler, defaults: UserDefaults, hour: Int) -> TrainerChangeNotifier {
        let now = date(hour: hour)
        return TrainerChangeNotifier(scheduler: scheduler, defaults: defaults, calendar: calendar, now: { now })
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "trainer-change-\(UUID())")!
    }

    private func easy(_ day: Day, meters: Double = 8_000) -> TrainerWorkout {
        TrainerWorkout(day: day, kind: .easy, title: "Rodagem \(Int(meters / 1_000)) km", totalMeters: meters, steps: [], rationale: "")
    }

    private func threshold(_ day: Day) -> TrainerWorkout {
        TrainerWorkout(
            day: day, kind: .threshold, title: "Limiar 9 km", totalMeters: 9_000,
            steps: [
                TrainerStep(kind: .warmup, meters: 2_000),
                TrainerStep(kind: .work, repeats: 4, meters: 1_000),
                TrainerStep(kind: .recovery, repeats: 3, meters: 600),
                TrainerStep(kind: .cooldown, meters: 1_200),
            ],
            rationale: ""
        )
    }

    @Test func pushesTomorrowChangeWithBlocksAndWatchStatus() async {
        let scheduler = FakeNotificationScheduler()
        let tomorrow = today.adding(days: 1)
        await notifier(scheduler, defaults: defaults(), hour: 10).notify(
            before: [easy(today), easy(tomorrow)], after: [easy(today), threshold(tomorrow)], today: today, done: [], watch: { _ in .current }
        )
        let id = "trainer-change-2026-11-21"
        #expect(await scheduler.delivered == [id])
        #expect(await scheduler.headers[id]?.title == "Treino de amanhã mudou")
        #expect(await scheduler.headers[id]?.link == "training://treinador/mudancas")
        #expect(await scheduler.scheduled[id]?.text == "Limiar 9 km: 4 × 1 km com recuperação de 600 m. O relógio já tem a versão nova.")
    }

    @Test func saysWhenTheWatchStillNeedsTheWorkout() async {
        let scheduler = FakeNotificationScheduler()
        await notifier(scheduler, defaults: defaults(), hour: 10).notify(
            before: [easy(today)], after: [threshold(today)], today: today, done: [], watch: { _ in .pending }
        )
        #expect(await scheduler.headers["trainer-change-2026-11-20"]?.title == "Treino de hoje mudou")
        #expect(await scheduler.scheduled["trainer-change-2026-11-20"]?.text == "Limiar 9 km: 4 × 1 km com recuperação de 600 m. Falta enviar ao relógio.")
    }

    @Test func ignoresUnchangedDoneAndDistantDays() async {
        let scheduler = FakeNotificationScheduler()
        let later = today.adding(days: 2)
        await notifier(scheduler, defaults: defaults(), hour: 10).notify(
            before: [easy(today), easy(today.adding(days: 1)), easy(later)],
            after: [threshold(today), easy(today.adding(days: 1)), threshold(later)],
            today: today, done: [today], watch: { _ in .none }
        )
        #expect(await scheduler.scheduled.isEmpty)
    }

    @Test func newChangeOnTheSameDayReplacesThePush() async {
        let scheduler = FakeNotificationScheduler()
        let notifier = notifier(scheduler, defaults: defaults(), hour: 10)
        await notifier.notify(before: [easy(today)], after: [easy(today, meters: 10_000)], today: today, done: [], watch: { _ in .none })
        await notifier.notify(before: [easy(today, meters: 10_000)], after: [threshold(today)], today: today, done: [], watch: { _ in .none })
        #expect(await scheduler.scheduled.count == 1)
        #expect(await scheduler.scheduled["trainer-change-2026-11-20"]?.text == "Limiar 9 km: 4 × 1 km com recuperação de 600 m.")
    }

    @Test func atNightTheMorningNoticeCarriesTheChange() async {
        let scheduler = FakeNotificationScheduler()
        let store = defaults()
        let tomorrow = today.adding(days: 1)
        await notifier(scheduler, defaults: store, hour: 23).notify(
            before: [easy(today), easy(tomorrow)], after: [threshold(today), threshold(tomorrow)], today: today, done: [], watch: { _ in .none }
        )
        #expect(await scheduler.scheduled.isEmpty)
        #expect(TrainerChangeNotifier.morningLine(defaults: store, day: "2026-11-21", run: "Tiros em 4:00–4:10.") == "Treino de hoje mudou: Tiros em 4:00–4:10.")
        #expect(TrainerChangeNotifier.morningLine(defaults: store, day: "2026-11-21", run: nil) == "Treino de hoje mudou: Limiar 9 km, 4 × 1 km com recuperação de 600 m.")
        #expect(TrainerChangeNotifier.morningLine(defaults: store, day: "2026-11-22", run: "Tiros em 4:00–4:10.") == "Tiros em 4:00–4:10.")
    }

    @Test func withMorningNoticeOffTheChangeWaitsForSeven() async {
        let scheduler = FakeNotificationScheduler()
        let store = defaults()
        store.set(false, forKey: BackgroundConstants.noticeEnabledDefaultsKey)
        let tomorrow = today.adding(days: 1)
        await notifier(scheduler, defaults: store, hour: 4).notify(
            before: [easy(today), easy(tomorrow)], after: [threshold(today), threshold(tomorrow)], today: today, done: [], watch: { _ in .none }
        )
        #expect(await scheduler.delivered.isEmpty)
        #expect(await scheduler.scheduled["trainer-change-2026-11-20"]?.at == date(hour: 7))
        #expect(await scheduler.headers["trainer-change-2026-11-20"]?.title == "Treino de hoje mudou")
        #expect(await scheduler.scheduled["trainer-change-2026-11-21"]?.at == date(hour: 7))
        #expect(await scheduler.headers["trainer-change-2026-11-21"]?.title == "Treino de amanhã mudou")
        #expect(TrainerChangeNotifier.morningLine(defaults: store, day: "2026-11-20", run: nil) == nil)
    }

    @Test func afterTheAutoSendThePendingPushGainsTheWatchLine() async {
        let scheduler = FakeNotificationScheduler()
        let store = defaults()
        store.set(false, forKey: BackgroundConstants.noticeEnabledDefaultsKey)
        let notifier = notifier(scheduler, defaults: store, hour: 4)
        await notifier.notify(before: [easy(today)], after: [threshold(today)], today: today, done: [], watch: { _ in .none })
        #expect(await scheduler.scheduled["trainer-change-2026-11-20"]?.text == "Limiar 9 km: 4 × 1 km com recuperação de 600 m.")
        await notifier.refresh([threshold(today), easy(today.adding(days: 1))], today: today, watch: { _ in .current })
        #expect(await scheduler.scheduled["trainer-change-2026-11-20"]?.text == "Limiar 9 km: 4 × 1 km com recuperação de 600 m. O relógio já tem a versão nova.")
        #expect(await scheduler.scheduled["trainer-change-2026-11-20"]?.at == date(hour: 7))
        #expect(await scheduler.scheduled["trainer-change-2026-11-21"] == nil)
    }

    @Test func refreshDuringTheDayLeavesDeliveredPushesAlone() async {
        let scheduler = FakeNotificationScheduler()
        let notifier = notifier(scheduler, defaults: defaults(), hour: 10)
        await notifier.notify(before: [easy(today)], after: [threshold(today)], today: today, done: [], watch: { _ in .none })
        await notifier.refresh([threshold(today)], today: today, watch: { _ in .current })
        #expect(await scheduler.scheduled["trainer-change-2026-11-20"]?.text == "Limiar 9 km: 4 × 1 km com recuperação de 600 m.")
    }

    @Test func morningNoticeAlreadyOutFallsBackToSeven() async {
        let scheduler = FakeNotificationScheduler()
        let store = defaults()
        store.set("2026-11-20", forKey: BackgroundConstants.notifiedDayDefaultsKey)
        await notifier(scheduler, defaults: store, hour: 5).notify(
            before: [easy(today)], after: [threshold(today)], today: today, done: [], watch: { _ in .none }
        )
        #expect(await scheduler.scheduled["trainer-change-2026-11-20"]?.at == date(hour: 7))
    }

    @Test func workoutThatDisappearsCancelsItsPendingPush() async {
        let scheduler = FakeNotificationScheduler()
        let store = defaults()
        let tomorrow = today.adding(days: 1)
        let id = "trainer-change-2026-11-21"
        await scheduler.schedule(id: id, text: "Limiar 9 km.", at: date(day: 21, hour: 7))
        store.set(tomorrow.iso, forKey: TrainerChangeNotifierConstants.morningDayKey)
        store.set("Limiar 9 km.", forKey: TrainerChangeNotifierConstants.morningSummaryKey)
        await notifier(scheduler, defaults: store, hour: 10).notify(
            before: [easy(today), threshold(tomorrow)], after: [easy(today)], today: today, done: [], watch: { _ in .none }
        )
        #expect(await scheduler.scheduled[id] == nil)
        #expect(TrainerChangeNotifier.morningLine(defaults: store, day: tomorrow.iso, run: "Rodagem.") == "Rodagem.")
    }

    @Test func withoutAPlanBothPendingPushesAreCancelled() async {
        let scheduler = FakeNotificationScheduler()
        let ids = ["trainer-change-2026-11-20", "trainer-change-2026-11-21"]
        for id in ids { await scheduler.schedule(id: id, text: "x", at: date(day: 21, hour: 7)) }
        let notifier = notifier(scheduler, defaults: defaults(), hour: 10)
        await notifier.refresh([easy(today)], today: today, watch: { _ in .none })
        #expect(await scheduler.scheduled[ids[0]] != nil)
        #expect(await scheduler.scheduled[ids[1]] == nil)
        await notifier.refresh([], today: today, watch: { _ in .none })
        #expect(await scheduler.scheduled[ids[0]] == nil)
    }

    private func plan() -> TrainerPlan {
        let target = TrainerTarget(kind: .race, name: "Meia", date: today.adding(days: 12 * 7), distanceMeters: 21_097.5, goalSeconds: 5_940)
        return TrainerEngine.create(
            target: target, structure: TrainerEngine.defaultStructure, strength: [], history: TrainerHistory(runs: []),
            today: today, now: date(hour: 9), startMeters: 50_000, peakMeters: 70_000
        )
    }

    private func version(_ number: Int, trigger: TrainerTrigger = .strengthChanged, summary: String = "Força mudou de dia.", day: Day) -> TrainerVersion {
        TrainerVersion(
            number: number, createdAt: date(hour: 9), trigger: trigger, summary: summary,
            changes: [TrainerChange(kind: .changed, day: day, title: "Rodagem", reason: "")]
        )
    }

    @Test func laterChangesGoOnlyToTheList() async {
        let scheduler = FakeNotificationScheduler()
        let now = date(hour: 10)
        let inbox = NoticeInboxStore(defaults: defaults(), calendar: calendar, now: { now })
        let notifier = TrainerChangeNotifier(scheduler: scheduler, inbox: inbox, defaults: defaults(), calendar: calendar, now: { now })
        let plan = plan()
        let later = version(2, day: today.adding(days: 3))
        let near = version(3, day: today.adding(days: 1))
        let signal = version(4, trigger: .weekEnded(1), summary: "Semana mais leve: HRV fora do seu normal.", day: today.adding(days: 4))
        notifier.recordLaterChanges([later, near, signal], plan: plan, today: today)
        notifier.recordLaterChanges([later], plan: plan, today: today)
        let entries = inbox.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.title == "Plano atualizado")
        #expect(entries.first?.text == "Força mudou de dia.")
        #expect(entries.first?.link == "training://treinador/mudancas")
        #expect(entries.first?.id.hasSuffix("-2") == true)
        #expect(await scheduler.scheduled.isEmpty)
    }

    private func nightNotifier(_ scheduler: FakeNotificationScheduler, morningOn: Bool) -> (TrainerChangeNotifier, UserDefaults) {
        let store = defaults()
        if !morningOn { store.set(false, forKey: BackgroundConstants.noticeEnabledDefaultsKey) }
        return (notifier(scheduler, defaults: store, hour: 23), store)
    }

    @Test func editAfterSchedulingRewritesThePendingPush() async {
        let scheduler = FakeNotificationScheduler()
        let (notifier, _) = nightNotifier(scheduler, morningOn: false)
        let tomorrow = today.adding(days: 1)
        let id = "trainer-change-2026-11-21"
        await notifier.notify(before: [easy(tomorrow)], after: [threshold(tomorrow)], today: today, done: [], watch: { _ in .none })
        #expect(await scheduler.scheduled[id]?.text.hasPrefix("Limiar 9 km") == true)
        await notifier.refresh([easy(tomorrow, meters: 10_000)], today: today, watch: { _ in .none })
        #expect(await scheduler.scheduled[id]?.text.hasPrefix("Rodagem 10 km") == true)
        #expect(await scheduler.scheduled[id]?.at == date(day: 21, hour: 7))
        #expect(await scheduler.headers[id]?.title == "Treino de hoje mudou")
    }

    @Test func undoingTheChangeCancelsThePendingPush() async {
        let scheduler = FakeNotificationScheduler()
        let (notifier, _) = nightNotifier(scheduler, morningOn: false)
        let tomorrow = today.adding(days: 1)
        await notifier.notify(before: [easy(tomorrow)], after: [threshold(tomorrow)], today: today, done: [], watch: { _ in .none })
        await notifier.notify(before: [threshold(tomorrow)], after: [easy(tomorrow, meters: 10_000)], today: today, done: [], watch: { _ in .none })
        await notifier.refresh([easy(tomorrow)], today: today, watch: { _ in .none })
        #expect(await scheduler.scheduled["trainer-change-2026-11-21"] == nil)
    }

    @Test func undoingTheChangeDropsTheMorningLine() async {
        let scheduler = FakeNotificationScheduler()
        let (notifier, store) = nightNotifier(scheduler, morningOn: true)
        let tomorrow = today.adding(days: 1)
        await notifier.notify(before: [easy(tomorrow)], after: [threshold(tomorrow)], today: today, done: [], watch: { _ in .none })
        #expect(TrainerChangeNotifier.morningLine(defaults: store, day: tomorrow.iso, run: nil) != nil)
        await notifier.refresh([easy(tomorrow, meters: 10_000)], today: today, watch: { _ in .none })
        #expect(TrainerChangeNotifier.morningLine(defaults: store, day: tomorrow.iso, run: nil)?.contains("Rodagem 10 km") == true)
        await notifier.refresh([easy(tomorrow)], today: today, watch: { _ in .none })
        #expect(TrainerChangeNotifier.morningLine(defaults: store, day: tomorrow.iso, run: "Rodagem.") == "Rodagem.")
    }

    @Test func refreshDropsTheWatchLineWhenTheWatchNoLongerNeedsIt() async {
        let scheduler = FakeNotificationScheduler()
        let (notifier, _) = nightNotifier(scheduler, morningOn: false)
        let tomorrow = today.adding(days: 1)
        let id = "trainer-change-2026-11-21"
        await notifier.notify(before: [easy(tomorrow)], after: [threshold(tomorrow)], today: today, done: [], watch: { _ in .pending })
        #expect(await scheduler.scheduled[id]?.text.hasSuffix("Falta enviar ao relógio.") == true)
        await notifier.refresh([threshold(tomorrow)], today: today, watch: { _ in .none })
        #expect(await scheduler.scheduled[id]?.text == "Limiar 9 km: 4 × 1 km com recuperação de 600 m.")
    }
}
