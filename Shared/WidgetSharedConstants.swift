import Foundation

enum WidgetSharedConstants {
    static let appGroup = "group.dev.aglv.training"
    static let fileName = "widget-snapshot.json"
    static let kind = "TrainingTodayWidget"
    static let deepLink = URL(string: "training://hoje")!

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.appending(path: fileName)
    }

    static func load() -> WidgetSnapshot {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return .empty }
        return snapshot
    }
}
