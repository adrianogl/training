import Foundation

struct NoticeInboxScheduler: NotificationScheduling {
    let base: any NotificationScheduling
    let inbox: NoticeInboxStore

    static var standard: NoticeInboxScheduler {
        NoticeInboxScheduler(base: UserNotificationScheduler(), inbox: NoticeInboxStore())
    }

    func pending() async -> [String] {
        await base.pending()
    }

    func schedule(id: String, text: String, at date: Date?) async {
        await base.schedule(id: id, text: text, at: date)
        inbox.record(id: id, title: nil, text: text, link: BackgroundConstants.readinessDeepLink, at: date)
    }

    func schedule(id: String, title: String?, text: String, link: String, at date: Date?) async {
        await base.schedule(id: id, title: title, text: text, link: link, at: date)
        inbox.record(id: id, title: title, text: text, link: link, at: date)
    }

    func schedule(id: String, title: String?, text: String, link: String, at date: Date?, category: String?) async {
        await base.schedule(id: id, title: title, text: text, link: link, at: date, category: category)
        inbox.record(id: id, title: title, text: text, link: link, at: date)
    }

    func scheduleDaily(id: String, title: String, text: String, link: String, hour: Int) async {
        await base.scheduleDaily(id: id, title: title, text: text, link: link, hour: hour)
        inbox.recordDaily(id: id, title: title, text: text, link: link, hour: hour)
    }

    func cancel(id: String) async {
        await base.cancel(id: id)
        inbox.removePending(id: id)
    }
}
