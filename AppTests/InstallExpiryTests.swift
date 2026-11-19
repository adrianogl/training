import Foundation
import SwiftUI
import Testing
@testable import trAIning

@MainActor @Suite struct InstallExpiryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(_ iso: String) -> Date { try! Date(iso, strategy: .iso8601) }

    private let expiry = try! Date("2026-11-26T16:21:07Z", strategy: .iso8601)

    @Test func readsTheExpirationInsideTheSignedProfile() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>ExpirationDate</key><date>2026-11-26T16:21:07Z</date><key>Name</key><string>x</string></dict></plist>
        """
        var data = Data([0x30, 0x82, 0x01, 0xFF, 0x00])
        data.append(Data(plist.utf8))
        data.append(Data([0x00, 0xA0, 0x82]))
        #expect(ProvisioningProfile.expiration(in: data) == expiry)
        #expect(ProvisioningProfile.expiration(in: Data("sem plist".utf8)) == nil)
    }

    @Test func showsTheNoticeOnTheLastTwoDays() {
        let model = { (now: String) in InstallExpiryModel(expiry: self.expiry, scheduler: FakeNotificationScheduler(), now: { self.date(now) }, calendar: self.calendar) }
        #expect(!model("2026-11-24T15:00:00Z").showsNotice)
        #expect(model("2026-11-25T11:00:00Z").showsNotice)
        #expect(model("2026-11-25T11:00:00Z").title == "O app para de abrir amanhã")
        #expect(model("2026-11-26T11:00:00Z").title == "O app para de abrir hoje")
        #expect(!model("2026-11-26T17:00:00Z").showsNotice)
        #expect(model("2026-11-25T11:00:00Z").text == "A instalação vence em 26/11. Deixe o aparelho desbloqueado na mesma rede do Mac ou conecte por cabo para instalar de novo.")
    }

    @Test func noProfileMeansNoNotice() async {
        let scheduler = FakeNotificationScheduler()
        let model = InstallExpiryModel(expiry: nil, scheduler: scheduler, now: { .now }, calendar: calendar)
        #expect(!model.showsNotice)
        await model.refresh()
        #expect(await scheduler.scheduled.isEmpty)
    }

    @Test func schedulesEightAMOnTheDayBeforeAndOnTheLastDay() async {
        let scheduler = FakeNotificationScheduler()
        let model = InstallExpiryModel(expiry: expiry, scheduler: scheduler, now: { self.date("2026-11-20T15:00:00Z") }, calendar: calendar)
        await model.refresh()
        let scheduled = await scheduler.scheduled
        #expect(scheduled["install-expiry-1"]?.at == date("2026-11-25T11:00:00Z"))
        #expect(scheduled["install-expiry-0"]?.at == date("2026-11-26T11:00:00Z"))
        #expect(scheduled["install-expiry-1"]?.text == "A instalação vence em 26/11. Deixe o aparelho perto do Mac para instalar de novo.")
        #expect(await scheduler.headers["install-expiry-0"]?.title == "O app para de abrir hoje")
    }

    @Test func reinstallMovesTheNotifications() async {
        let scheduler = FakeNotificationScheduler()
        await InstallExpiryModel(expiry: expiry, scheduler: scheduler, now: { self.date("2026-11-25T15:00:00Z") }, calendar: calendar).refresh()
        #expect(await scheduler.scheduled["install-expiry-0"] != nil)
        let renewed = date("2026-12-01T16:00:00Z")
        await InstallExpiryModel(expiry: renewed, scheduler: scheduler, now: { self.date("2026-11-25T15:30:00Z") }, calendar: calendar).refresh()
        #expect(await scheduler.scheduled["install-expiry-0"]?.at == date("2026-12-01T11:00:00Z"))
        #expect(await scheduler.scheduled["install-expiry-1"]?.at == date("2026-11-30T11:00:00Z"))
    }

    @Test func noticeRenders() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let model = InstallExpiryModel(expiry: expiry, scheduler: FakeNotificationScheduler(), now: { self.date("2026-11-25T11:00:00Z") }, calendar: calendar)
        let view = InstallExpiryNotice(title: model.title, text: model.text)
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: view.padding(16).frame(width: 390).background(BrandColors.background).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "install-expiry-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
    }
}
