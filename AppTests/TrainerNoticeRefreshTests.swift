import Foundation
import Insights
import Storage
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct TrainerNoticeRefreshTests {
    private static let monday = Day(iso: "2026-11-16")!
    private static let tuesday = monday.adding(days: 1)

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private static let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10))!
    private static let evening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 20))!
    private static let night = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 23))!

    private static let target = TrainerTarget(
        kind: .race, name: "Meia de Floripa", date: monday.adding(days: 16 * TrainerConstants.weekdayCount), distanceMeters: 21_097.5, goalSeconds: 5_940
    )

    private static func model(_ scheduler: FakeNotificationScheduler, defaults: UserDefaults, now: Date = morning) throws -> TrainerModel {
        let today = monday
        let inbox = NoticeInboxStore(defaults: defaults, calendar: calendar, now: { now })
        let store = TrainerStore(
            url: FileManager.default.temporaryDirectory.appending(path: "trainer-notices-\(UUID().uuidString).json"), defaults: defaults
        )
        return TrainerModel(
            container: try TrainingSchema.container(inMemory: true), store: store, today: { today }, defaults: defaults,
            changeNotifier: TrainerChangeNotifier(scheduler: scheduler, inbox: inbox, defaults: defaults, calendar: calendar, now: { now }),
            heatNotifier: LongHeatNotifier(scheduler: scheduler, calendar: calendar, now: { now }),
            watchPendingNotifier: WatchPendingNotifier(scheduler: scheduler, inbox: inbox, calendar: calendar, now: { now })
        )
    }

    private static func planned(_ scheduler: FakeNotificationScheduler, defaults: UserDefaults, now: Date = morning) async throws -> TrainerModel {
        let model = try model(scheduler, defaults: defaults, now: now)
        await model.createPlan(target: target, structure: TrainerEngine.defaultStructure, strength: [], startMeters: 60_000, peakMeters: 80_000)
        await model.settleNotices()
        return model
    }

    private static func defaults() -> UserDefaults {
        UserDefaults(suiteName: "trainer-notices-\(UUID())")!
    }

    @Test func deletingThePlanCancelsTheScheduledNotices() async throws {
        let scheduler = FakeNotificationScheduler()
        let model = try await Self.planned(scheduler, defaults: Self.defaults())
        let ids = ["long-heat-", "watch-pending-", "trainer-change-"].map { $0 + Self.tuesday.iso } + ["trainer-change-" + Self.monday.iso]
        for id in ids { await scheduler.schedule(id: id, text: "x", at: Self.evening) }
        model.deletePlan()
        await model.settleNotices()
        for id in ids { #expect(await scheduler.scheduled[id] == nil) }
    }

    @Test func switchingToAppleWatchCancelsTheGarminNotice() async throws {
        let scheduler = FakeNotificationScheduler()
        let defaults = Self.defaults()
        WatchKind.garmin.store(in: defaults)
        TrainerSendStore(defaults: defaults).save(TrainerSendSettings(runFromTrainer: true, auto: nil, includesMFIT: false))
        let model = try await Self.planned(scheduler, defaults: defaults)
        model.hasGarminAccount = { true }
        let id = "watch-pending-" + Self.tuesday.iso
        await model.refreshNotices()
        #expect(await scheduler.scheduled[id] != nil)
        WatchKind.appleWatch.store(in: defaults)
        model.scheduleNoticeRefresh()
        await model.settleNotices()
        #expect(await scheduler.scheduled[id] == nil)
    }

    @Test func savingThePlanRefreshesTheGarminNotice() async throws {
        let scheduler = FakeNotificationScheduler()
        let defaults = Self.defaults()
        WatchKind.garmin.store(in: defaults)
        TrainerSendStore(defaults: defaults).save(TrainerSendSettings(runFromTrainer: true, auto: nil, includesMFIT: false))
        let model = try await Self.planned(scheduler, defaults: defaults)
        let id = "watch-pending-" + Self.tuesday.iso
        #expect(await scheduler.scheduled[id] == nil)
        model.hasGarminAccount = { true }
        await model.toggleLightWeek(Self.monday.adding(days: 2 * TrainerConstants.weekdayCount))
        await model.settleNotices()
        #expect(await scheduler.scheduled[id] != nil)
    }

    @Test func switchingToAppleWatchDropsTheWatchLineFromTheChangePush() async throws {
        let scheduler = FakeNotificationScheduler()
        let defaults = Self.defaults()
        defaults.set(false, forKey: BackgroundConstants.noticeEnabledDefaultsKey)
        WatchKind.garmin.store(in: defaults)
        TrainerSendStore(defaults: defaults).save(TrainerSendSettings(runFromTrainer: true, auto: nil, includesMFIT: false))
        let model = try await Self.planned(scheduler, defaults: defaults, now: Self.night)
        model.hasGarminAccount = { true }
        let workout = try #require(model.plan?.workouts.first { $0.day == Self.tuesday })
        var older = workout
        older.title = "Treino antigo"
        older.totalMeters += 2_000
        let now = Self.night
        let notifier = TrainerChangeNotifier(
            scheduler: scheduler, inbox: NoticeInboxStore(defaults: defaults, calendar: Self.calendar, now: { now }), defaults: defaults,
            calendar: Self.calendar, now: { now }
        )
        await notifier.notify(before: [older], after: [workout], today: Self.monday, done: [], watch: { _ in .pending })
        let id = "trainer-change-" + Self.tuesday.iso
        #expect(await scheduler.scheduled[id]?.text.hasSuffix("Falta enviar ao relógio.") == true)
        await model.refreshNotices()
        #expect(await scheduler.scheduled[id]?.text.hasSuffix("Falta enviar ao relógio.") == true)
        WatchKind.appleWatch.store(in: defaults)
        model.scheduleNoticeRefresh()
        await model.settleNotices()
        #expect(await scheduler.scheduled[id]?.text.contains("relógio") == false)
        #expect(await scheduler.scheduled[id]?.at == Self.calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 7)))
    }
}
