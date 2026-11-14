import Foundation

enum SyncStatusPillText {
    static func content(for status: SyncStatus, showsFinished: Bool) -> SyncStatusPillContent? {
        switch status {
        case .idle:
            return nil
        case .running(let progress):
            let percent = Int((min(max(progress, 0), 1) * 100).rounded())
            return SyncStatusPillContent(
                kind: .syncing,
                title: SyncStatusPillConstants.syncingTitle,
                detail: percent > 0 ? "\(percent)%" : nil
            )
        case .finished:
            guard showsFinished else { return nil }
            return SyncStatusPillContent(kind: .updated, title: SyncStatusPillConstants.updatedTitle, detail: nil)
        case .failed:
            return SyncStatusPillContent(
                kind: .failed,
                title: SyncStatusPillConstants.failedTitle,
                detail: SyncStatusPillConstants.failedDetail
            )
        }
    }
}
