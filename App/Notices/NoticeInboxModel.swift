import Foundation
import Observation

@MainActor @Observable final class NoticeInboxModel {
    private(set) var entries: [NoticeEntry] = []

    @ObservationIgnored private let store: NoticeInboxStore
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    init(store: NoticeInboxStore) {
        self.store = store
        reload()
        observer = NotificationCenter.default.addObserver(forName: NoticeInboxConstants.changedNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    var unreadCount: Int { entries.filter { !$0.isRead }.count }

    var fresh: [NoticeEntry] { entries.filter { !$0.isRead } }

    var earlier: [NoticeEntry] { entries.filter(\.isRead) }

    func reload() {
        let current = store.entries()
        if current != entries { entries = current }
    }

    func markAllRead() {
        store.markAllRead()
        reload()
    }

    func open(_ entry: NoticeEntry) {
        store.markRead(id: entry.id)
        reload()
        if let url = URL(string: entry.link) { DeepLinkCenter.shared.open(url) }
    }
}
