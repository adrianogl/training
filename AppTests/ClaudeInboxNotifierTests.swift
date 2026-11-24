import Foundation
import Testing
@testable import trAIning

@MainActor @Suite struct ClaudeInboxNotifierTests {
    @Test func notifiesOncePerBatchAndOpensStrength() async {
        let defaults = UserDefaults(suiteName: "claude-inbox-\(UUID())")!
        let scheduler = FakeNotificationScheduler()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 10))!
        let notifier = ClaudeInboxNotifier(scheduler: scheduler, defaults: defaults, calendar: calendar, now: { now })
        let mailbox = ClaudeMailbox(defaults: defaults)
        mailbox.receive(ClaudeInbox(json: "{}", savedAt: Date(timeIntervalSince1970: 1)))
        await notifier.check()
        await notifier.check()
        #expect(await scheduler.delivered == [ClaudeConstants.inboxNotificationId])
        #expect(await scheduler.headers[ClaudeConstants.inboxNotificationId]?.link == "training://treinador/forca")
        mailbox.receive(ClaudeInbox(json: "{}", savedAt: Date(timeIntervalSince1970: 2)))
        await notifier.check()
        #expect(await scheduler.delivered.count == 2)
        mailbox.markSeen(ClaudeInbox(json: "{}", savedAt: Date(timeIntervalSince1970: 3)))
        mailbox.receive(ClaudeInbox(json: "{}", savedAt: Date(timeIntervalSince1970: 3)))
        await notifier.check()
        #expect(await scheduler.delivered.count == 2)
    }

    @Test func applyingOrDiscardingRemovesNoticeFromInbox() async {
        let defaults = UserDefaults(suiteName: "claude-inbox-\(UUID())")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 10))!
        let inbox = NoticeInboxStore(defaults: defaults, calendar: calendar, now: { now })
        let scheduler = NoticeInboxScheduler(base: FakeNotificationScheduler(), inbox: inbox)
        let notifier = ClaudeInboxNotifier(scheduler: scheduler, defaults: defaults, calendar: calendar, now: { now })
        let mailbox = ClaudeMailbox(defaults: defaults)
        let batch = ClaudeInbox(json: "{}", savedAt: Date(timeIntervalSince1970: 1))
        mailbox.receive(batch)
        await notifier.check()
        #expect(inbox.entries().map(\.id) == [ClaudeConstants.inboxNotificationId])
        mailbox.markSeen(batch)
        #expect(inbox.entries().isEmpty)
    }

    @Test func titleCountsTheWorkouts() {
        #expect(ClaudeInboxNotifierText.title(count: 1) == "1 treino de força do Claude")
        #expect(ClaudeInboxNotifierText.title(count: 3) == "3 treinos de força do Claude")
    }
}
