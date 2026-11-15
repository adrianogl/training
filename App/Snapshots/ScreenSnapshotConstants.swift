import Foundation

enum ScreenSnapshotConstants {
    static let schemaVersion = 1
    static let directoryName = "ScreenSnapshots"
    static let fileExtension = "json"
    static let refreshingLabel = "Atualizando"
    static let refreshingSpacing: CGFloat = 6
    static let refreshingBottomPadding: CGFloat = 10

    static var defaultDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return caches.appending(path: directoryName, directoryHint: .isDirectory)
    }
}
