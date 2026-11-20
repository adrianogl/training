import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

private final class SignalClock: @unchecked Sendable {
    var day: Day

    init(_ day: Day) {
        self.day = day
    }
}

@MainActor
@Suite struct TrainerSignalNotifierTests {
    private static let monday = Day(iso: "2026-11-16")!
    private static let calendar = Calendar.current

    private static let halfMarathon = TrainerTarget(
        kind: .race, name: "Meia de Floripa", date: monday.adding(days: 16 * TrainerConstants.weekdayCount),
        distanceMeters: 21_097.5, goalSeconds: 5_940
    )

    private static func date(_ day: Day, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour))!
    }

    private struct Setup {
        let model: TrainerModel
        let scheduler: FakeNotificationScheduler
        let clock: SignalClock
        let defaults: UserDefaults
        let container: ModelContainer
    }

    private static func makeSetup(hour: Int = 12) throws -> Setup {
        let clock = SignalClock(monday)
        let defaults = UserDefaults(suiteName: "trainer-signal-\(UUID().uuidString)")!
        let scheduler = FakeNotificationScheduler()
        let notifier = TrainerSignalNotifier(
            scheduler: scheduler, defaults: defaults, calendar: calendar, now: { date(clock.day, hour: hour) }
        )
        let store = TrainerStore(
            url: FileManager.default.temporaryDirectory.appending(path: "trainer-signal-\(UUID().uuidString).json"),
            defaults: defaults
        )
        let container = try TrainingSchema.container(inMemory: true)
        let model = TrainerModel(container: container, store: store, today: { clock.day }, defaults: defaults, signalNotifier: notifier)
        return Setup(model: model, scheduler: scheduler, clock: clock, defaults: defaults, container: container)
    }

    private static func insertTiredWeek(_ container: ModelContainer) throws {
        let context = ModelContext(container)
        for offset in 1...60 {
            let day = monday.adding(days: -offset)
            context.insert(DailyRecord(day: day.iso, restingHR: 50, hrvLastNight: offset.isMultiple(of: 2) ? 60 : 70, sleepSeconds: 28_800))
        }
        for offset in 0..<7 {
            let day = monday.adding(days: offset)
            context.insert(DailyRecord(day: day.iso, restingHR: 50, hrvLastNight: 55, sleepSeconds: 25_200))
        }
        try context.save()
    }

    private static func createHalf(_ model: TrainerModel) async {
        await model.createPlan(
            target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], startMeters: 60_000, peakMeters: 80_000
        )
    }

    private static let expectedText = "Semana mais leve: HRV e sono fora do seu normal."

    @Test func signalWeekSchedulesOneNotificationWithTheReason() async throws {
        let setup = try Self.makeSetup()
        try Self.insertTiredWeek(setup.container)
        await Self.createHalf(setup.model)
        setup.clock.day = Self.monday.adding(days: TrainerConstants.weekdayCount)
        let created = await setup.model.autoAdjust()
        #expect(created.map(\.trigger) == [.weekEnded(1)])
        let scheduled = await setup.scheduler.scheduled
        #expect(scheduled.count == 1)
        let id = try #require(scheduled.keys.first)
        #expect(scheduled[id]?.text == Self.expectedText)
        #expect(scheduled[id]?.at == nil)
        let headers = await setup.scheduler.headers
        #expect(headers[id]?.title == "Plano atualizado")
        #expect(headers[id]?.link == "training://treinador/mudancas")
    }

    @Test func secondAdjustOnTheSameDayDoesNotNotifyAgain() async throws {
        let setup = try Self.makeSetup()
        try Self.insertTiredWeek(setup.container)
        await Self.createHalf(setup.model)
        setup.clock.day = Self.monday.adding(days: TrainerConstants.weekdayCount)
        await setup.model.autoAdjust()
        await setup.model.autoAdjust()
        await setup.model.load()
        #expect(await setup.scheduler.delivered.count == 1)
    }

    @Test func sameVersionSeenByAnotherNotifierIsNotNotifiedTwice() async throws {
        let setup = try Self.makeSetup()
        try Self.insertTiredWeek(setup.container)
        await Self.createHalf(setup.model)
        setup.clock.day = Self.monday.adding(days: TrainerConstants.weekdayCount)
        await setup.model.autoAdjust()
        let plan = try #require(setup.model.plan)
        let other = FakeNotificationScheduler()
        let notifier = TrainerSignalNotifier(scheduler: other, defaults: setup.defaults, calendar: Self.calendar)
        await notifier.notify(plan.versions, plan: plan)
        #expect(await other.scheduled.isEmpty)
        #expect(await setup.scheduler.delivered.count == 1)
    }

    @Test func endedPlanDoesNotNotify() async throws {
        let setup = try Self.makeSetup()
        try Self.insertTiredWeek(setup.container)
        await Self.createHalf(setup.model)
        setup.clock.day = Self.monday.adding(days: 3)
        await setup.model.endCycle()
        setup.clock.day = Self.monday.adding(days: TrainerConstants.weekdayCount)
        await setup.model.autoAdjust()
        #expect(await setup.scheduler.scheduled.isEmpty)
    }

    @Test func weekWithoutSignalsDoesNotNotify() async throws {
        let setup = try Self.makeSetup()
        await Self.createHalf(setup.model)
        setup.clock.day = Self.monday.adding(days: TrainerConstants.weekdayCount)
        let created = await setup.model.autoAdjust()
        #expect(created.map(\.trigger) == [.weekEnded(1)])
        #expect(await setup.scheduler.scheduled.isEmpty)
    }

    @Test func nightAdjustWaitsUntilSevenInTheMorning() async throws {
        let setup = try Self.makeSetup(hour: 4)
        try Self.insertTiredWeek(setup.container)
        await Self.createHalf(setup.model)
        let nextMonday = Self.monday.adding(days: TrainerConstants.weekdayCount)
        setup.clock.day = nextMonday
        await setup.model.autoAdjust()
        let scheduled = await setup.scheduler.scheduled
        #expect(scheduled.values.first?.at == Self.date(nextMonday, hour: 7))
    }

    @Test func lateEveningMovesToTheNextMorning() {
        let day = Self.monday
        let notifier = TrainerSignalNotifier(
            scheduler: FakeNotificationScheduler(), defaults: UserDefaults(suiteName: "trainer-signal-\(UUID().uuidString)")!,
            calendar: Self.calendar, now: { Self.date(day, hour: 23) }
        )
        #expect(notifier.deliveryDate() == Self.date(day.adding(days: 1), hour: 7))
    }

    private static func version(_ trigger: TrainerTrigger, summary: String) -> TrainerVersion {
        TrainerVersion(number: 3, createdAt: .now, trigger: trigger, summary: summary, changes: [])
    }

    @Test func bannerShowsTheSignalReason() {
        let calm = Self.version(.weekEnded(2), summary: "\(Self.expectedText) Longão fica em 14 km.")
        #expect(TrainerText.triggerText(calm) == Self.expectedText)
        let early = Self.version(.weekEnded(2), summary: "Semana leve antecipada: HRV e FC de repouso fora do seu normal.")
        #expect(TrainerText.triggerText(early) == "Semana leve antecipada: HRV e FC de repouso fora do seu normal.")
        #expect(TrainerText.triggerText(Self.version(.weekEnded(2), summary: "Semana fechada.")) == "fim da semana 2")
        #expect(TrainerText.triggerText(Self.version(.strengthChanged, summary: Self.expectedText)) == "treinos de força atualizados")
    }
}
