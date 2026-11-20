import Foundation
import Testing
@testable import trAIning

@MainActor @Suite struct InstallNoticeTests {
    private let release = AppRelease(versao: "1.26.0", build: 35, versao_app: "1.26.0", notas: ["Avisa quando instala", "Abre a prontidão pela notificação", "Três", "Quatro"])
    private let expiry = Date(timeIntervalSince1970: 1_800_000_000)

    private func defaults(lastVersion: String? = nil, lastExpiry: Date? = nil, ranBefore: Bool = true) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "install-\(UUID())")!
        if let lastVersion { defaults.set(lastVersion, forKey: InstallNoticeConstants.versionDefaultsKey) }
        if let lastExpiry { defaults.set(lastExpiry, forKey: InstallNoticeConstants.expiryDefaultsKey) }
        if ranBefore { defaults.set(Date(), forKey: AppUpdateConstants.lastCheckDefaultsKey) }
        defaults.set(try! JSONEncoder().encode(release), forKey: AppUpdateConstants.releaseDefaultsKey)
        return defaults
    }

    private func model(_ defaults: UserDefaults, version: String = "1.26.0", expiry: Date? = nil, background: Bool, scheduler: FakeNotificationScheduler) -> InstallNoticeModel {
        InstallNoticeModel(
            defaults: defaults, version: version, expiry: expiry ?? self.expiry, scheduler: scheduler, isActive: { !background }, settle: {},
            now: { Date(timeIntervalSince1970: 1_799_900_000) }, calendar: Calendar(identifier: .gregorian)
        )
    }

    @Test func newVersionInBackgroundNotifiesWithNotesAndOpensSettings() async {
        let scheduler = FakeNotificationScheduler()
        let event = await model(defaults(lastVersion: "1.25.0"), background: true, scheduler: scheduler).check()
        #expect(event == .updated(version: "1.26.0", notes: ["Avisa quando instala", "Abre a prontidão pela notificação", "Três"]))
        #expect(await scheduler.delivered == [InstallNoticeConstants.notificationId])
        let header = await scheduler.headers[InstallNoticeConstants.notificationId]
        #expect(header?.title == "trAIning 1.26.0 instalado")
        #expect(header?.link == "training://ajustes")
        #expect(await scheduler.scheduled[InstallNoticeConstants.notificationId]?.text == "Novidades: Avisa quando instala. Abre a prontidão pela notificação. Três.")
    }

    @Test func newVersionInForegroundShowsTheCardOnce() async {
        let scheduler = FakeNotificationScheduler()
        let store = defaults(lastVersion: "1.25.0")
        let model = model(store, background: false, scheduler: scheduler)
        await model.check()
        #expect(model.showsCard)
        #expect(model.card?.version == "1.26.0")
        #expect(await scheduler.delivered.isEmpty)
        model.dismiss()
        #expect(!model.showsCard)
        #expect(await self.model(store, background: false, scheduler: scheduler).check() == nil)
    }

    @Test func freshInstallStaysQuiet() async {
        let event = await model(defaults(ranBefore: false), background: true, scheduler: FakeNotificationScheduler()).check()
        #expect(event == nil)
    }

    @Test func firstRunAfterUpdatingFromAnOldBuildCountsAsUpdate() {
        let event = InstallNoticeModel.event(lastVersion: nil, lastExpiry: nil, version: "1.26.0", expiry: expiry, ranBefore: true, release: release)
        #expect(event == .updated(version: "1.26.0", notes: ["Avisa quando instala", "Abre a prontidão pela notificação", "Três"]))
    }

    @Test func notesOnlyWhenTheAppChangedSinceTheLastVersion() {
        let serverOnly = AppRelease(versao: "1.26.1", build: 36, versao_app: "1.26.0", notas: ["Velha"])
        #expect(InstallNoticeModel.notes(release: serverOnly, from: "1.26.0", to: "1.26.1").isEmpty)
        #expect(InstallNoticeModel.notes(release: serverOnly, from: "1.25.0", to: "1.26.1") == ["Velha"])
        #expect(InstallNoticeModel.notes(release: release, from: "1.24.0", to: "1.25.0").isEmpty)
    }

    @Test func sameVersionWithNewProfileIsARenewal() async {
        let scheduler = FakeNotificationScheduler()
        let renewed = expiry.addingTimeInterval(5 * 86_400)
        let event = await model(defaults(lastVersion: "1.26.0", lastExpiry: expiry), expiry: renewed, background: true, scheduler: scheduler).check()
        #expect(event == .renewed(expiry: renewed))
        let header = await scheduler.headers[InstallNoticeConstants.notificationId]
        #expect(header?.title == "Instalação renovada")
        #expect(header?.link == "training://hoje")
    }

    @Test func sameInstallStaysQuiet() async {
        let event = await model(defaults(lastVersion: "1.26.0", lastExpiry: expiry), background: true, scheduler: FakeNotificationScheduler()).check()
        #expect(event == nil)
    }
}
