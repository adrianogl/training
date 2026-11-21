import Foundation
import Testing
@testable import trAIning

@MainActor @Suite struct AppUpdateTests {
    private let release = AppRelease(versao: "1.11.0", build: 16, versao_app: "1.11.0", notas: ["Avisa quando há versão nova", "Corrige a semana", "Terceira", "Quarta"])

    private func model(installed: String, release: AppRelease? = nil, now: Date = Date(timeIntervalSince1970: 1_800_000_000), scheduler: FakeNotificationScheduler = FakeNotificationScheduler(), calls: FetchCounter = FetchCounter()) -> (AppUpdateModel, UserDefaults) {
        let defaults = UserDefaults(suiteName: "update-\(UUID())")!
        let data = try! JSONEncoder().encode(release ?? self.release)
        let model = AppUpdateModel(
            defaults: defaults, installed: installed, scheduler: scheduler,
            fetch: { _ in await calls.increment(); return data },
            url: URL(string: "https://x.dev/versao.json")!, now: { now }, calendar: Calendar(identifier: .gregorian)
        )
        return (model, defaults)
    }

    @Test func comparesVersionsByNumber() {
        #expect(AppVersion.isNewer("1.10.0", than: "1.9.0"))
        #expect(AppVersion.isNewer("2.0", than: "1.99.9"))
        #expect(!AppVersion.isNewer("1.9.0", than: "1.9.0"))
        #expect(!AppVersion.isNewer("1.9.0", than: "1.10.0"))
        #expect(!AppVersion.isNewer("", than: "1.0.0"))
    }

    @Test func onlyWarnsWhenTheAppChanged() {
        let serverOnly = AppRelease(versao: "1.10.0", build: 15, versao_app: "1.9.0", notas: [])
        #expect(AppVersion.update(for: serverOnly, installed: "1.9.0") == nil)
        #expect(AppVersion.update(for: serverOnly, installed: "1.8.0")?.latest == "1.10.0")
        #expect(AppVersion.update(for: release, installed: "1.10.0")?.notes.count == 3)
    }

    @Test func refreshFindsTheUpdateAndSchedulesTheDailyNotification() async {
        let scheduler = FakeNotificationScheduler()
        let (model, defaults) = model(installed: "1.9.0", scheduler: scheduler)
        await model.refresh()
        #expect(model.update == AppUpdate(latest: "1.11.0", installed: "1.9.0", notes: ["Avisa quando há versão nova", "Corrige a semana", "Terceira"]))
        #expect(model.showsNotice)
        let daily = await scheduler.daily[AppUpdateConstants.notificationId]
        #expect(daily?.hour == 8)
        #expect(daily?.title == "Versão 1.11.0 disponível")
        #expect(daily?.text == "Este aparelho está na 1.9.0. Instale pelo Mac para receber as novidades.")
        #expect(daily?.link == "training://hoje")
        #expect(defaults.data(forKey: AppUpdateConstants.releaseDefaultsKey) != nil)
    }

    @Test func upToDateCancelsTheNotification() async {
        let scheduler = FakeNotificationScheduler()
        await scheduler.scheduleDaily(id: AppUpdateConstants.notificationId, title: "x", text: "x", link: "x", hour: 8)
        let (model, _) = model(installed: "1.11.0", scheduler: scheduler)
        await model.refresh()
        #expect(model.update == nil)
        #expect(await scheduler.daily[AppUpdateConstants.notificationId] == nil)
    }

    @Test func checksAtMostEverySixHoursUnlessForced() async {
        let calls = FetchCounter()
        let (model, _) = model(installed: "1.9.0", calls: calls)
        await model.refresh()
        await model.refresh()
        #expect(await calls.value == 1)
        await model.refresh(force: true)
        #expect(await calls.value == 2)
    }

    @Test func dismissHidesTheNoticeUntilTomorrow() async {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let (first, defaults) = model(installed: "1.9.0", now: day)
        await first.refresh()
        first.dismiss()
        #expect(!first.showsNotice)
        let next = AppUpdateModel(
            defaults: defaults, installed: "1.9.0", scheduler: FakeNotificationScheduler(), fetch: { _ in Data() },
            url: URL(string: "https://x.dev/versao.json")!, now: { day.addingTimeInterval(86_400) }, calendar: Calendar(identifier: .gregorian)
        )
        #expect(next.update?.latest == "1.11.0")
        #expect(next.showsNotice)
    }

    @Test func noticeTextFollowsTheMock() {
        let update = AppUpdate(latest: "1.11.0", installed: "1.9.0", notes: ["Nota"])
        #expect(AppUpdateText.noticeText(update) == "Este aparelho está na 1.9.0. Instale pelo Mac para receber as novidades:")
    }
}

private actor FetchCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}
