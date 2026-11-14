enum SyncStatusPillKind: Equatable {
    case syncing
    case updated
    case failed
}

struct SyncStatusPillContent: Equatable {
    let kind: SyncStatusPillKind
    let title: String
    let detail: String?

    var text: String {
        [title, detail].compactMap { $0 }.joined(separator: SyncStatusPillConstants.separator)
    }
}
